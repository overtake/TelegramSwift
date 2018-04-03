//
//  PassportController.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 20/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import PostboxMac
import SwiftSignalKitMac


private let _id_street1 = InputDataIdentifier("street1")
private let _id_street2 = InputDataIdentifier("street2")
private let _id_postcode = InputDataIdentifier("postcode")
private let _id_city = InputDataIdentifier("city")
private let _id_region = InputDataIdentifier("region")

private let _id_delete = InputDataIdentifier("delete")

private let _id_name = InputDataIdentifier("name")
private let _id_surname = InputDataIdentifier("surname")
private let _id_birthday = InputDataIdentifier("birthday")
private let _id_issue_date = InputDataIdentifier("issue_date")
private let _id_expire_date = InputDataIdentifier("expire_date")

private let _id_country = InputDataIdentifier("country")
private let _id_id_number = InputDataIdentifier("id_number")
private let _id_gender = InputDataIdentifier("_id_gender")

private let _id_email_code = InputDataIdentifier("email_code")
private let _id_email_new = InputDataIdentifier("email_new")
private let _id_email_def = InputDataIdentifier("email_default")

private let _id_phone_code = InputDataIdentifier("_id_phone_code")
private let _id_phone_new = InputDataIdentifier("_id_phone_new")
private let _id_phone_def = InputDataIdentifier("_id_phone_def")

private let _id_c_password = InputDataIdentifier("create_password")
private let _id_c_repassword = InputDataIdentifier("create_re_password")
private let _id_c_email = InputDataIdentifier("create_email")
private let _id_c_hint = InputDataIdentifier("hint")


enum SecureIdErrorTarget : String {
    case data = "data"
    case files = "files"
}

private final class SecureIdError : Equatable {
    let target:SecureIdErrorTarget
    let text: String
    let field: String
    init(target: SecureIdErrorTarget, text: String, field: String) {
        self.target = target
        self.text = text
        self.field = field
    }
}

private func ==(lhs: SecureIdError, rhs: SecureIdError) -> Bool {
    return lhs.target == rhs.target && lhs.text == rhs.text && lhs.field == rhs.field
}

private final class PassportArguments {
    let account: Account
    let checkPassword:((String, ()->Void))->Void
    let requestField:(SecureIdRequestedFormField, SecureIdValueKey?, [SecureIdRequestedFormField])->Void
    let createPassword: ()->Void
    let abortVerification: ()-> Void
    let authorize:()->Void
    let botPrivacy:()->Void
    init(account: Account, checkPassword:@escaping((String, ()->Void))->Void, requestField:@escaping(SecureIdRequestedFormField, SecureIdValueKey?, [SecureIdRequestedFormField])->Void, createPassword: @escaping()->Void, abortVerification: @escaping()->Void, authorize: @escaping()->Void, botPrivacy:@escaping()->Void) {
        self.account = account
        self.checkPassword = checkPassword
        self.requestField = requestField
        self.createPassword = createPassword
        self.abortVerification = abortVerification
        self.botPrivacy = botPrivacy
        self.authorize = authorize
    }
}

private enum PassportEntryId : Hashable {
    case header
    case loading
    case sectionId(Int32)
    case emptyField(SecureIdRequestedFormField)
    case filledField(SecureIdRequestedFormField)
    case description(Int32)
    case accept
    case requestPassword
    case createPassword
    var hashValue: Int {
        return 0
    }
}

private func ==(lhs: PassportEntryId, rhs: PassportEntryId) -> Bool {
    switch lhs {
    case .header:
        if case .header = rhs {
            return true
        } else {
            return false
        }
    case .loading:
        if case .loading = rhs {
            return true
        } else {
            return false
        }
    case let .emptyField(type):
        if case .emptyField(type) = rhs {
            return true
        } else {
            return false
        }
    case let .filledField(type):
        if case .filledField(type) = rhs {
            return true
        } else {
            return false
        }
    case let .description(id):
        if case .description(id) = rhs {
            return true
        } else {
            return false
        }
    case .requestPassword:
        if case .requestPassword = rhs {
            return true
        } else {
            return false
        }
    case .createPassword:
        if case .createPassword = rhs {
            return true
        } else {
            return false
        }
    case .accept:
        if case .accept = rhs {
            return true
        } else {
            return false
        }
    case let .sectionId(id):
        if case .sectionId(id) = rhs {
            return true
        } else {
            return false
        }
    }
}

private enum PassportEntry : TableItemListNodeEntry {
    case header(sectionId: Int32, index: Int32, requestedFields: [SecureIdRequestedFormField], peer: Peer)
    case accept(sectionId: Int32, index: Int32, enabled: Bool)
    case emptyField(sectionId: Int32, index: Int32, fieldType: SecureIdRequestedFormField, relative: [SecureIdRequestedFormField])
    case filledField(sectionId: Int32, index: Int32, fieldType: SecureIdRequestedFormField, relative: [SecureIdRequestedFormField], description: String, value: SecureIdValue)
    case description(sectionId: Int32, index: Int32, text: String)
    case requestPassword(sectionId: Int32, index: Int32)
    case createPassword(sectionId: Int32, index: Int32, peer: Peer)
    case loading
    case sectionId(Int32)
    
    var stableId: PassportEntryId {
        switch self {
        case .header:
            return .header
        case let .emptyField(_, _, fieldType, _):
            return .emptyField(fieldType)
        case let .filledField(_, _, fieldType, _, _, _):
            return .filledField(fieldType)
        case let .description(_, index, _):
            return .description(index)
        case .accept:
            return .accept
        case .loading:
            return .loading
        case .requestPassword:
            return .requestPassword
        case .createPassword:
            return .createPassword
        case .sectionId(let id):
            return .sectionId(id)
        }
    }
    
    var index: Int32 {
        switch self {
        case let .header(section, index, _, _):
            return (section * 1000) + index
        case let .emptyField(section, index, _, _):
            return (section * 1000) + index
        case let .accept(section, index, _):
            return (section * 1000) + index
        case let .filledField(section, index, _, _, _, _):
            return (section * 1000) + index
        case let .description(section, index, _):
            return (section * 1000) + index
        case let .requestPassword(section, index):
            return (section * 1000) + index
        case let .createPassword(section, index, _):
            return (section * 1000) + index
        case .loading:
            return 0
        case let .sectionId(section):
            return (section + 1) * 1000 - section
        }
    }
    
    func item(_ arguments: PassportArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .header(_, _, requestedFields, peer):
            return PassportHeaderItem(initialSize, account: arguments.account, stableId: stableId, requestedFields: requestedFields, peer: peer)
        case let .emptyField(_, _, fieldType, relative):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: fieldType.rawValue, description: fieldType.rawDescription, type: .none, action: {
                arguments.requestField(fieldType, nil, relative)
            })
        case let .accept(_, _, enabled):
            return PassportAcceptRowItem(initialSize, stableId: stableId, enabled: enabled, action: {
                arguments.authorize()
            })
        case let .filledField(_, _, fieldType, relative, description,value):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: fieldType.rawValue, description: description, type: .selectable(stateback: { return true}), action: {
                arguments.requestField(fieldType, value.key, relative)
            })
        case .requestPassword:
            return PassportInsertPasswordItem(initialSize, stableId: stableId, checkPasswordAction: arguments.checkPassword)
        case .createPassword(_, _, let peer):
            return PassportTwoStepVerificationIntroItem(initialSize, stableId: stableId, peer: peer, action: arguments.createPassword)
        case let .description(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { link in
                switch link {
                case "abortVerification":
                    arguments.abortVerification()
                case "_applyPrivacy_":
                    arguments.botPrivacy()
                default:
                    break
                }
            }))
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        }
    }
}

private func <(lhs: PassportEntry, rhs: PassportEntry) -> Bool {
    return lhs.index < rhs.index
}

private func ==(lhs: PassportEntry, rhs: PassportEntry) -> Bool {
    switch lhs {
    case let .header(lhsSectionId, lhsIndex, lhsRequestedFields, lhsPeer):
        if case let .header(rhsSectionId, rhsIndex, rhsRequestedFields, rhsPeer) = rhs {
            return lhsSectionId == rhsSectionId && lhsIndex == rhsIndex && lhsRequestedFields == rhsRequestedFields && lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    case let .accept(sectionId, index, enabled):
        if case .accept(sectionId, index, enabled) = rhs {
            return true
        } else {
            return false
        }
    case let .emptyField(sectionId, index, fieldType, lhsRelative):
        if case .emptyField(sectionId, index, fieldType, let rhsRelative) = rhs {
            return lhsRelative == rhsRelative
        } else {
            return false
        }
    case let .filledField(sectionId, index, fieldType, lhsRelative, description, lhsValue):
        if case .filledField(sectionId, index, fieldType, let rhsRelative, description, let rhsValue) = rhs {
            return lhsValue.isSame(of: rhsValue) && lhsRelative == rhsRelative
        } else {
            return false
        }
    case let .description(sectionId, index, text):
        if case .description(sectionId, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .requestPassword(sectionId, index):
        if case .requestPassword(sectionId, index) = rhs {
            return true
        } else {
            return false
        }
    case let .createPassword(sectionId, index, lhsPeer):
        if case .createPassword(sectionId, index, let rhsPeer) = rhs {
            return lhsPeer.isEqual(rhsPeer)
        } else {
            return false
        }
    case .loading:
        if case .loading = rhs {
            return true
        } else {
            return false
        }
    case let .sectionId(id):
        if case .sectionId(id) = rhs {
            return true
        } else {
            return false
        }
    }
}

private func passportEntries(encryptedForm: EncryptedSecureIdForm?, form: SecureIdForm?, peer: Peer, passwordData: TwoStepVerificationConfiguration?, state: PassportState) -> [PassportEntry] {
    var entries:[PassportEntry] = []
    
    if let _ = passwordData {
        var sectionId: Int32 = 0
        var index: Int32 = 0
        if state.passwordSettings == nil, let form = encryptedForm {
            if let passwordData = passwordData {
                switch passwordData {
                case let .notSet(pendingEmailPattern):
                    
                    entries.append(.sectionId(sectionId))
                    sectionId += 1
                    
                    if pendingEmailPattern.isEmpty {
                        entries.append(.createPassword(sectionId: sectionId, index: index, peer: peer))
                        index += 1
                    } else {
                        let emailText = L10n.twoStepAuthConfirmationText + "\n\n[\(tr(L10n.twoStepAuthConfirmationAbort))](abortVerification)"
                        entries.append(.description(sectionId: sectionId, index: index, text: emailText))
                        index += 1
                    }
                case .set:
                    
                    
                    entries.append(.header(sectionId: sectionId, index: index, requestedFields: form.requestedFields, peer: peer))
                    index += 1
               
                    entries.append(.sectionId(sectionId))
                    sectionId += 1
                    
                    entries.append(.requestPassword(sectionId: sectionId, index: index))
                    index += 1
                }
            }
            
        } else if let form = form {
            
            entries.append(.header(sectionId: sectionId, index: index, requestedFields: form.requestedFields, peer: peer))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            //TODOLANG
            entries.append(.description(sectionId: sectionId, index: index, text: L10n.secureIdRequestedInformationHeader))
            index += 1
            
            var filledCount: Int32 = 0
            
            let relativeAddress:[SecureIdRequestedFormField] = form.requestedFields.filter({ value in
                switch value {
                case .rentalAgreement, .utilityBill, .bankStatement:
                    return true
                default:
                    return false
                }
            })
            
            let relativeIdentity:[SecureIdRequestedFormField] = form.requestedFields.filter({ value in
                switch value {
                case .passport, .driversLicense, .idCard:
                    return true
                default:
                    return false
                }
            })
            
            for field in form.requestedFields {
                if let value = state.searchValue(field.valueKey) {
                    switch value {
                    case let .address(address):
                        let values = [address.street1, address.city, address.countryCode].compactMap {$0}.filter {!$0.isEmpty}
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: relativeAddress, description: values.joined(separator: ", "), value: value))
                        index += 1
                        filledCount += 1
                    case let .email(email):
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: [], description: email.email, value: value))
                        index += 1
                        filledCount += 1
                    case let .personalDetails(details):
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: relativeIdentity, description: details.firstName + " " + details.lastName, value: value))
                        index += 1
                        filledCount += 1
                    case let .phone(phone):
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: [], description: formatPhoneNumber(phone.phone), value: value))
                        index += 1
                        filledCount += 1
                    default:
                        break
                    }
                } else {
                    switch field {
                    case .address:
                        entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative: relativeAddress))
                        index += 1
                    case .email:
                        entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative: []))
                        index += 1
                    case .personalDetails:
                        entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative: relativeIdentity))
                        index += 1
                    case .phone:
                        entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative: []))
                        index += 1
                    default:
                        break
                    }
                    
                }
            }
            
            entries.append(.description(sectionId: sectionId, index: index, text: L10n.secureIdAcceptPolicy(peer.addressName ?? "")))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(.accept(sectionId: sectionId, index: index, enabled: filledCount == form.requestedFields.count - relativeAddress.count - relativeIdentity.count))
            index += 1
        }
       
    } else {
        entries.append(.loading)
    }
    
    return entries
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PassportEntry>], right: [AppearanceWrapperEntry<PassportEntry>], initialSize:NSSize, arguments: PassportArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private final class EmailIntermediateState : Equatable {
    let email: String
    init(email: String) {
        self.email = email
    }
}

private func ==(lhs: EmailIntermediateState, rhs: EmailIntermediateState) -> Bool {
    return lhs.email == rhs.email
}


private final class DetailsIntermediateState : Equatable {
    let firstName: InputDataValue
    let lastName: InputDataValue
    let birthday: InputDataValue
    let countryCode: InputDataValue
    let gender: InputDataValue
    let issueDate:InputDataValue?
    let expiryDate: InputDataValue?
    
    init(firstName: InputDataValue, lastName: InputDataValue, birthday: InputDataValue, countryCode: InputDataValue, gender: InputDataValue, issueDate: InputDataValue?, expiryDate: InputDataValue?) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthday = birthday
        self.countryCode = countryCode
        self.gender = gender
        self.issueDate = issueDate
        self.expiryDate = expiryDate
    }
}

private func ==(lhs: DetailsIntermediateState, rhs: DetailsIntermediateState) -> Bool {
    return lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName && lhs.birthday == rhs.birthday && lhs.countryCode == rhs.countryCode && lhs.gender == rhs.gender && lhs.issueDate == rhs.issueDate && lhs.expiryDate == rhs.expiryDate
}

private final class AddressIntermediateState : Equatable {
    let street1: InputDataValue
    let street2: InputDataValue
    let city: InputDataValue
    let region: InputDataValue
    let countryCode: InputDataValue
    let postcode: InputDataValue
    
    init(street1: InputDataValue, street2: InputDataValue, city: InputDataValue, region: InputDataValue, countryCode: InputDataValue, postcode: InputDataValue) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.region = region
        self.countryCode = countryCode
        self.postcode = postcode
    }
}

private func ==(lhs: AddressIntermediateState, rhs: AddressIntermediateState) -> Bool {
    return lhs.street1 == rhs.street1 && lhs.street2 == rhs.street2 && lhs.city == rhs.city && lhs.region == rhs.region && lhs.countryCode == rhs.countryCode && lhs.postcode == rhs.postcode
}

private final class PassportState : Equatable {
    let account: Account
    let peer: Peer
    let values:[SecureIdValueWithContext]
    let accessContext: SecureIdAccessContext?
    let password: UpdateTwoStepVerificationPasswordResult?
    let passwordSettings: TwoStepVerificationSettings?
    let verifyDocumentContext: SecureIdVerificationDocumentsContext?
    let files: [SecureIdValueKey : [SecureIdVerificationDocument]]
    
    let emailIntermediateState: EmailIntermediateState?
    
    let detailsIntermediateState: DetailsIntermediateState?
    let addressIntermediateState: AddressIntermediateState?
    
    let errors:[SecureIdValueKey: [SecureIdError]]
    
    init(account: Account, peer: Peer, errors: [SecureIdValueKey: [SecureIdError]], passwordSettings:TwoStepVerificationSettings? = nil, password: UpdateTwoStepVerificationPasswordResult? = nil, values: [SecureIdValueWithContext] = [], accessContext: SecureIdAccessContext? = nil, verifyDocumentContext: SecureIdVerificationDocumentsContext? = nil, files: [SecureIdValueKey : [SecureIdVerificationDocument]] = [:], emailIntermediateState: EmailIntermediateState? = nil, detailsIntermediateState: DetailsIntermediateState? = nil, addressIntermediateState: AddressIntermediateState? = nil) {
        self.account = account
        self.peer = peer
        self.errors = errors
        self.passwordSettings = passwordSettings
        self.password = password
        self.values = values
        self.accessContext = accessContext
        self.verifyDocumentContext = verifyDocumentContext
        self.files = files
        self.emailIntermediateState = emailIntermediateState
        self.detailsIntermediateState = detailsIntermediateState
        self.addressIntermediateState = addressIntermediateState
        
        self.verifyDocumentContext?.stateUpdated(files.reduce([], { (current, value) -> [SecureIdVerificationDocument] in
            return current + value.value
        }))
    }
    
    func searchValue(_ valueKey: SecureIdValueKey) -> SecureIdValue? {
        let index = values.index { value -> Bool in
            return value.value.isSame(of: valueKey)
        }
        if let index = index {
            return values[index].value
        }
        return nil
    }
    
    
    func withUpdatedPassword(_ password: UpdateTwoStepVerificationPasswordResult?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedPasswordSettings(_ settings: TwoStepVerificationSettings?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: settings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    
    func withUpdatedValues(_ values:[SecureIdValueWithContext]) -> PassportState {
        var current = self
        for value in values {
            current = current.withUpdatedValue(value)
        }
        return current
    }
    
    func withUpdatedValue(_ value: SecureIdValueWithContext) -> PassportState {
        var values = self.values
        let index = values.index { v -> Bool in
            return value.value.isSame(of: v.value)
        }
        if let index = index {
            values[index] = value
        } else {
            values.append(value)
        }
        
        var files = self.files
        if let verificationDocuments = value.value.verificationDocuments {
            files[value.value.key] = verificationDocuments.compactMap { reference in
                switch reference {
                case let .remote(file):
                    return .remote(file)
                default:
                    return nil
                }
            }
        }
        
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withRemovedValue(_ key: SecureIdValueKey) -> PassportState {
        var values = self.values
        let index = values.index { v -> Bool in
            return v.value.key == key
        }
        if let index = index {
            values.remove(at: index)
        }
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedAccessContext(_ accessContext: SecureIdAccessContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedVerifyDocumentContext(_ verifyDocumentContext: SecureIdVerificationDocumentsContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedFileState(id: Int64, state: SecureIdVerificationLocalDocumentState) -> PassportState {
        var files = self.files
        for (key, documents) in files {
            loop: for i in  0 ..< documents.count {
                let file = documents[i]
                if file.id.hashValue == id {
                    switch file {
                    case var .local(document):
                        document.state = state
                        var documents = documents
                        documents[i] = .local(document)
                        files[key] = documents
                        break loop
                    default:
                        break
                    }
                }
            }
        }
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withAppendFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var current = self.files[valueKey] ?? []
        current.append(contentsOf: files)
        var dictionary = self.files
        dictionary[valueKey] = current
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var dictionary = self.files
        dictionary[valueKey] = files
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withRemovedFile(_ file: SecureIdVerificationDocument, for valueKey: SecureIdValueKey) -> PassportState {
        var files = self.files[valueKey]
        if let _ = files {
            for i in 0 ..< files!.count {
                if files![i].id == file.id {
                    files!.remove(at: i)
                    break
                }
            }
        }
        var dictionary = self.files
        dictionary[valueKey] = files
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedIntermediateEmailState(_ emailIntermediateState: EmailIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    
    func withUpdatedDetailsState(_ detailsIntermediateState: DetailsIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
    func withUpdatedAddressState(_ addressState: AddressIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState)
    }
}
private func ==(lhs: PassportState, rhs: PassportState) -> Bool {
    
    if lhs.files.count != rhs.files.count {
        return false
    } else {
        for (lhsKey, lhsValue) in lhs.files {
            let rhsValue = rhs.files[lhsKey]
            if let rhsValue = rhsValue {
                if lhsValue.count != rhsValue.count {
                    return false
                } else {
                    for i in 0 ..< lhsValue.count {
                        if !lhsValue[i].isEqual(to: rhsValue[i]) {
                            return false
                        }
                    }
                }
                
            } else {
                return false
            }
        }
    }
    
    
    return lhs.passwordSettings?.email == rhs.passwordSettings?.email && lhs.password == rhs.password && lhs.values == rhs.values && (lhs.accessContext == nil && rhs.accessContext == nil) && lhs.emailIntermediateState == rhs.emailIntermediateState && lhs.detailsIntermediateState == rhs.detailsIntermediateState && lhs.addressIntermediateState == rhs.addressIntermediateState && lhs.errors == rhs.errors
}



private func createPasswordEntries( _ state: PassportState) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    let nonFilter:(String)->String = { value in
        return value
    }
    //TODOLANG
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordHeader))
    index += 1
    
    
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), identifier: _id_c_password, mode: .secure, placeholder: L10n.secureIdCreatePasswordPasswordPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordPasswordInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value:  .string(""), identifier: _id_c_repassword, mode: .secure, placeholder: "", inputPlaceholder: L10n.secureIdCreatePasswordRePasswordInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1

    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordDescription))
    index += 1

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordHintHeader))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), identifier: _id_c_hint, mode: .plain, placeholder: L10n.secureIdCreatePasswordHintPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordHintInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordEmailHeader))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), identifier: _id_c_email, mode: .plain, placeholder: L10n.secureIdCreatePasswordEmailPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordEmailInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordEmailDescription))
    index += 1
    
    return entries
    
}


private func emailEntries( _ state: PassportState, updateState: @escaping ((PassportState)->PassportState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    if let email = state.emailIntermediateState?.email, !email.isEmpty {
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), identifier: _id_email_code, mode: .plain, placeholder: L10n.secureIdEmailActivateCodePlaceholder, inputPlaceholder: L10n.secureIdEmailActivateCodeInputPlaceholder, filter: {$0}, limit: 254))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdEmailActivateDescription(email)))
        index += 1
        
        return entries
        
    } else  if let email = state.passwordSettings?.email, !email.isEmpty {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(email), identifier: _id_email_def, name: L10n.secureIdEmailUseSame(email), color: theme.colors.blueUI, type: .next))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), identifier: _id_email_new, mode: .plain, placeholder: L10n.secureIdEmailEmailPlaceholder, inputPlaceholder: L10n.secureIdEmailEmailInputPlaceholder, filter: {$0}, limit: 254))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdEmailUseSameDesc))
    index += 1
    
    
    return entries
}


private func phoneNumberEntries( _ state: PassportState, updateState: @escaping ((PassportState)->PassportState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    //
    if let phone = (state.peer as? TelegramUser)?.phone, !phone.isEmpty {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(phone), identifier: _id_phone_def, name: L10n.secureIdPhoneNumberUseSame(formatPhoneNumber(phone)), color: theme.colors.blueUI, type: .next))
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberUseSameDesc))
        index += 1
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberHeader))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(""), identifier: _id_phone_new, item: { initialSize, stableId -> TableRowItem in
        return PassportNewPhoneNumberRowItem(initialSize, stableId: stableId, action: {
            
        })
    }))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberNote))
    index += 1
    
    
    return entries
}

private func confirmPhoneNumberEntries( _ state: PassportState, phoneNumber: String, updateState: @escaping ((PassportState)->PassportState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1

    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberHeader))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(nil), identifier: _id_phone_code, mode: .plain, placeholder: L10n.secureIdPhoneNumberConfirmCodePlaceholder, inputPlaceholder: L10n.secureIdPhoneNumberConfirmCodeInputPlaceholder, filter: { (text) -> String in
        return text.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
    }, limit: 6))
    
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberConfirmCodeDesc(formatPhoneNumber(phoneNumber))))
    index += 1
    
    
    return entries
}

private func addressEntries( _ state: PassportState, relative: SecureIdRequestedFormField?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    let nonFilter:(String)->String = { value in
        return value
    }
    
    
    let address: SecureIdAddressValue? = state.searchValue(.address)?.addressValue
    let relativeValue: SecureIdValue? = relative == nil ? nil : state.searchValue(relative!.valueKey)
    
    
    if let relative = relative {
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdScansHeader))
        index += 1
        
        let files = state.files[relative.valueKey] ?? []
        
        var fileIndex: Int32 = 0
        
        if let accessContext = state.accessContext {
            for file in files {
                let header = L10n.secureIdScanNumber(Int(fileIndex + 1))
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(file), identifier: InputDataIdentifier("_file_\(fileIndex)"), item: { initialSize, stableId -> TableRowItem in
                    return PassportDocumentRowItem(initialSize, stableId: stableId, account: state.account, accessContext: accessContext, document: file, header: header, removeAction: { value in
                        updateState { current in
                            return current.withRemovedFile(value, for: relative.valueKey)
                        }
                    })
                }))
                fileIndex += 1
                index += 1
            }
            if files.count > 0 {
                entries.append(.sectionId(sectionId))
                sectionId += 1
            }
        }
        
        
        entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), identifier: InputDataIdentifier("scan"), placeholder: files.count > 0 ? L10n.secureIdUploadAdditionalScan : L10n.secureIdUploadScan, action: {
            filePanel(with: photoExts, allowMultiple: true, for: mainWindow, completion: { files in
                if let files = files {
                    let localFiles:[SecureIdVerificationDocument] = files.map({SecureIdVerificationDocument.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                    
                    updateState { current in
                        return current.withAppendFiles(localFiles, for: relative.valueKey)
                    }
                }
            })
        }))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityScanDescription))
        index += 1
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    
    //TODOLANG
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdAddressHeader))
    index += 1
    
    
    //
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.street1 ?? .string(address?.street1), identifier: _id_street1, mode: .plain, placeholder: L10n.secureIdAddressStreetPlaceholder, inputPlaceholder: L10n.secureIdAddressStreetInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.street2 ?? .string(address?.street2), identifier: _id_street2, mode: .plain, placeholder: "", inputPlaceholder: L10n.secureIdAddressStreet1InputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.city ?? .string(address?.city), identifier: _id_city, mode: .plain, placeholder: L10n.secureIdAddressCityPlaceholder, inputPlaceholder: L10n.secureIdAddressCityInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.region ?? .string(address?.region), identifier: _id_region, mode: .plain, placeholder: L10n.secureIdAddressRegionPlaceholder, inputPlaceholder: L10n.secureIdAddressRegionInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    let filedata = try! String(contentsOfFile: Bundle.main.path(forResource: "countries", ofType: nil)!)
    
    let countries: [ValuesSelectorValue<InputDataValue>] = filedata.components(separatedBy: "\n").compactMap { country in
        let entry = country.components(separatedBy: "|")
        if entry.count == 2 {
            return ValuesSelectorValue(localized: entry[1], value: .string(entry[0]))
        } else {
            return nil
        }
    }
    
    entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.addressIntermediateState?.countryCode ?? .string(address?.countryCode), identifier: _id_country, placeholder: L10n.secureIdAddressCountryPlaceholder, values: countries))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.postcode ?? .string(address?.postcode), identifier: _id_postcode, mode: .plain, placeholder: L10n.secureIdAddressPostcodePlaceholder, inputPlaceholder: L10n.secureIdAddressPostcodeInputPlaceholder, filter: { text in
        return text.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
    }, limit: 10))
    index += 1
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    if let _ = address {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), identifier: _id_delete, name: L10n.secureIdDeleteAddress, color: theme.colors.redUI, type: .none))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }

    return entries
    
}

private func identityEntries( _ state: PassportState, relative: SecureIdRequestedFormField?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    let nonFilter:(String)->String = { value in
        return value
    }
    
    let personalDetails: SecureIdPersonalDetailsValue? = state.searchValue(.personalDetails)?.personalDetails
    let relativeValue: SecureIdValue? = relative == nil ? nil : state.searchValue(relative!.valueKey)
    
    
    if let relative = relative {
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdScansHeader))
        index += 1
        
        let files = state.files[relative.valueKey] ?? []
        
        var fileIndex: Int32 = 0
        
        if let accessContext = state.accessContext {
            for file in files {
                let header = L10n.secureIdScanNumber(Int(fileIndex + 1))
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(file), identifier: InputDataIdentifier("_file_\(fileIndex)"), item: { initialSize, stableId -> TableRowItem in
                    return PassportDocumentRowItem(initialSize, stableId: stableId, account: state.account, accessContext: accessContext, document: file, header: header, removeAction: { value in
                        updateState { current in
                            return current.withRemovedFile(value, for: relative.valueKey)
                        }
                    })
                }))
                fileIndex += 1
                index += 1
            }
            if files.count > 0 {
                entries.append(.sectionId(sectionId))
                sectionId += 1
            }
        }
        
        
        entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), identifier: InputDataIdentifier("scan"), placeholder: files.count > 0 ? L10n.secureIdUploadAdditionalScan : L10n.secureIdUploadScan, action: {
            filePanel(with: photoExts, allowMultiple: true, for: mainWindow, completion: { files in
                if let files = files {
                    let localFiles:[SecureIdVerificationDocument] = files.map({SecureIdVerificationDocument.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                    
                    updateState { current in
                        return current.withAppendFiles(localFiles, for: relative.valueKey)
                    }
                }
            })
        }))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityScanDescription))
        index += 1
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    
    
    
    //TODOLANG
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdDocumentDetailsHeader))
    index += 1
    
    
//
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.firstName ?? .string(personalDetails?.firstName ?? ""), identifier: _id_name, mode: .plain, placeholder: L10n.secureIdPlaceholderFirstName, inputPlaceholder: L10n.secureIdInputPlaceholderFirstName, filter: nonFilter, limit: 255))
    index += 1

    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.lastName ?? .string(personalDetails?.lastName ?? ""), identifier: _id_surname, mode: .plain, placeholder: L10n.secureIdPlaceholderLastName, inputPlaceholder: L10n.secureIdInputPlaceholderLastName, filter: nonFilter, limit: 255))
    index += 1

    let genders:[ValuesSelectorValue<InputDataValue>] = [ValuesSelectorValue(localized: L10n.secureIdGenderMale, value: .gender(.male)), ValuesSelectorValue(localized: L10n.secureIdGenderFemale, value: .gender(.female))]

    entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.gender ?? .gender(personalDetails?.gender), identifier: _id_gender, placeholder: L10n.secureIdPlaceholderGender, values: genders))
    index += 1

    entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.birthday ?? personalDetails?.birthdate.inputDataValue ?? .date(nil, nil, nil), identifier: _id_birthday, placeholder: L10n.secureIdPlaceholderBirthday))
    index += 1

    
    let filedata = try! String(contentsOfFile: Bundle.main.path(forResource: "countries", ofType: nil)!)
    
    let countries: [ValuesSelectorValue<InputDataValue>] = filedata.components(separatedBy: "\n").compactMap { country in
        let entry = country.components(separatedBy: "|")
        if entry.count == 2 {
            return ValuesSelectorValue(localized: entry[1], value: .string(entry[0]))
        } else {
            return nil
        }
    }
    
    entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.countryCode ?? .string(personalDetails?.countryCode), identifier: _id_country, placeholder: L10n.secureIdPlaceholderCountry, values: countries))
    index += 1

    if let _ = relative {
        entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.issueDate ?? relativeValue?.issueDate?.inputDataValue ?? .date(nil, nil, nil), identifier: _id_issue_date, placeholder: L10n.secureIdPlaceholderIssuedDate))
        index += 1
        
        entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.expiryDate ?? relativeValue?.expiryDate?.inputDataValue ?? .date(nil, nil, nil), identifier: _id_expire_date, placeholder: L10n.secureIdPlaceholderExpiryDate))
        index += 1
    }

    

    entries.append(.sectionId(sectionId))
    sectionId += 1
   
    if let _ = personalDetails {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), identifier: _id_delete, name: L10n.secureIdDeleteIdentity, color: theme.colors.redUI, type: .none))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }


    
    return entries
}

class PassportController: TableViewController {

    private let form: EncryptedSecureIdForm
    private let disposable = MetaDisposable()
    private let peer: Peer
    private let request: inAppSecureIdRequest
    init(_ account: Account, _ peer: Peer, request: inAppSecureIdRequest, _ form: EncryptedSecureIdForm) {
        self.form = form
        self.peer = peer
        self.request = request
        super.init(account)
        
        //bar = .init(height: 0)
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func backSettings() -> (String, CGImage?) {
        return (L10n.navigationCancel, nil)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        let inAppRequest = self.request
        let encryptedForm = self.form
        let formValue: Promise<(EncryptedSecureIdForm?, SecureIdForm?)> = Promise()
        
        formValue.set(.single((form, nil)))
        
        let initialSize = self.atomicSize
        let account = self.account
        
        let actionsDisposable = DisposableSet()
        let checkPassword = MetaDisposable()
        let authorizeDisposable = MetaDisposable()
        let emailNewActivationDisposable = MetaDisposable()
        let phoneNewActivationDisposable = MetaDisposable()

        actionsDisposable.add(checkPassword)
        actionsDisposable.add(authorizeDisposable)
        actionsDisposable.add(emailNewActivationDisposable)
        actionsDisposable.add(phoneNewActivationDisposable)
        
        var errors:[SecureIdValueKey : [SecureIdError]] = [:]
        if let raw = request.errors {
            for row in raw {
                var valueKey:SecureIdValueKey?
                if let type = row["type"], let field = row["field"], let rawTarget = row["target"], let text = row["description"]  {
                    switch type {
                    case "personal_details":
                        valueKey = .personalDetails
                    case "passport":
                        valueKey = .passport
                    case "drivers_license":
                        valueKey = .driversLicense
                    case "idCard":
                        valueKey = .idCard
                    case "address":
                        valueKey = .address
                    case "utility_bill":
                        valueKey = .utilityBill
                    case "bank_statement":
                        valueKey = .bankStatement
                    case "rental_agreement":
                        valueKey = .rentalAgreement
                    case "phone":
                        valueKey = .phone
                    case "email":
                        valueKey = .email
                    default:
                        break
                    }
                    if let valueKey = valueKey, let target = SecureIdErrorTarget(rawValue: rawTarget) {
                        var _errors:[SecureIdError] = errors[valueKey] ?? []
                        _errors.append(SecureIdError(target: target, text: text, field: field))
                        errors[valueKey] = _errors
                    }
                }
                
            }
        }
        let state:ValuePromise<PassportState> = ValuePromise(PassportState(account: account, peer: peer, errors: errors), ignoreRepeated: true)
        
        let stateValue:Atomic<PassportState> = Atomic(value: PassportState(account: account, peer: peer, errors: errors))
        
        var _stateValue: PassportState {
            return stateValue.modify({$0})
        }
        
        let updateState:((PassportState)->PassportState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        let closeAfterSuccessful:()->Void = { [weak self] in
            self?.window?.closeInterceptor?()
        }
        
        
        let passwordVerificationData: Promise<TwoStepVerificationConfiguration?> = Promise()
        passwordVerificationData.set(.single(nil) |> then(twoStepVerificationConfiguration(account: account) |> map {Optional($0)}))
        
        
        let emailActivation = MetaDisposable()
        let saveValueDisposable = MetaDisposable()
        actionsDisposable.add(emailActivation)
        actionsDisposable.add(saveValueDisposable)
        
        let updateVerifyDocumentState: (Int64, SecureIdVerificationLocalDocumentState) -> Void = { id, state in
            updateState { current in
                return current.withUpdatedFileState(id: id, state: state)
            }
        }
        
        emailActivation.set((isKeyWindow.get() |> deliverOnPrepareQueue |> mapToSignal { _ in return combineLatest(passwordVerificationData.get() |> take(1) |> deliverOnPrepareQueue, state.get() |> take(1) |> deliverOnPrepareQueue) }).start(next: { config, state in
            if let config = config {
                switch config {
                case let .notSet(email):
                    if !email.isEmpty, let password = state.password {
                        switch password {
                        case let .password(password, _):
                            passwordVerificationData.set( twoStepVerificationConfiguration(account: account) |> mapToSignal { config in
                                switch config {
                                case .set:
                                    return accessSecureId(network: account.network, password: password) |> map { context in
                                        return (decryptedSecureIdForm(context: context, form: encryptedForm), context)
                                        } |> deliverOnMainQueue |> mapToSignal { (form, context) in
                                            return requestTwoStepVerifiationSettings(network: account.network, password: password) |> mapError {_ in return SecureIdAccessError.generic} |> map { settings in
                                                return (form, context, settings)
                                            }
                                    } |> map { form, context, settings in
                                        updateState { current in
                                            var current = current
                                            if let form = form {
                                                current = form.values.reduce(current, { current, value -> PassportState in
                                                    return current.withUpdatedValue(value)
                                                })
                                            }
                                            return current.withUpdatedAccessContext(context).withUpdatedPasswordSettings(settings).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                                        }
                                        formValue.set(.single((nil, form)))
                                        return Optional(config)
                                    } |> mapError {_ in return}
                                default:
                                    return .single(Optional(config))
                                }
                                })
                        default:
                            break
                        }
                    } else if !email.isEmpty {
                        passwordVerificationData.set(twoStepVerificationConfiguration(account: account) |> map {Optional($0)})
                    }
                default:
                    break
                }
            }
        }))
        

        let presentController:(ViewController)->Void = { [weak self] controller in
            self?.navigationController?.push(controller)
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<PassportEntry>]> = Atomic(value: [])
        
        
        let arguments = PassportArguments(account: account, checkPassword: { value, shake in
            checkPassword.set(showModalProgress(signal: accessSecureId(network: account.network, password: value) |> map { context in
                return (decryptedSecureIdForm(context: context, form: encryptedForm), context)
                } |> deliverOnMainQueue |> mapToSignal { (form, context) in
                    return requestTwoStepVerifiationSettings(network: account.network, password: value) |> mapError {_ in return SecureIdAccessError.generic} |> map { settings in
                        return (form, context, settings)
                    }
                }, for: mainWindow).start(next: { form, context, settings in
                updateState { current in
                    var current = current
                    if let form = form {
                        current = form.values.reduce(current, { current, value -> PassportState in
                            return current.withUpdatedValue(value)
                        })
                    }
                    return current.withUpdatedAccessContext(context).withUpdatedPasswordSettings(settings).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                }
                formValue.set(.single((nil, form)))
            }, error: { error in
                 alert(for: mainWindow, info: "\(error)")
            }))
            
            
        }, requestField: { field, valueKey, relative in
            
            
            let proccessValue:([SecureIdValue])->InputDataValidation = { values in
                return .fail(.doSomething(next: { f in
                    
                    let signal: Signal<[SecureIdValueWithContext], SaveSecureIdValueError> = state.get() |> take(1) |> mapError {_ in return SaveSecureIdValueError.generic} |> mapToSignal { state in
                        if let context = state.accessContext {
                            return combineLatest(values.map({saveSecureIdValue(network: account.network, context: context, value: $0)}))
                        } else {
                            return .fail(.generic)
                        }
                        } |> deliverOnMainQueue
                    
                    saveValueDisposable.set(showModalProgress(signal: signal, for: mainWindow).start(next: { values in
                        updateState { current in
                            return values.reduce(current, { current, value in
                                return current.withUpdatedValue(value)
                            })
                        }
                        f(.success(.navigationBack))
                    }, error: { error in
                        f(.fail(.alert("\(error)")))
                    }))
                }))
            }
            
            let removeValue:(SecureIdValueKey) -> Void = { valueKey in
                saveValueDisposable.set(showModalProgress(signal: deleteSecureIdValues(network: account.network, keys: Set(arrayLiteral: valueKey)), for: mainWindow).start(completed: {
                    updateState { current in
                        return current.withRemovedValue(valueKey)
                    }
                }))
            }
            
            let removeValueInteractive:(SecureIdValueKey) -> InputDataValidation = { valueKey in
                return .fail(.doSomething { f in
                    saveValueDisposable.set(showModalProgress(signal: deleteSecureIdValues(network: account.network, keys: Set(arrayLiteral: valueKey)) |> deliverOnMainQueue, for: mainWindow).start(completed: {
                        updateState { current in
                            return current.withRemovedValue(valueKey)
                        }
                        f(.success(.navigationBack))
                    }))
                })
            }
            
            switch field {
            case .address:
                let push:(SecureIdRequestedFormField, SecureIdRequestedFormField?) -> Void = { field, relative in
                    presentController(InputDataController(account, dataSignal: state.get() |> map { state in
                        return addressEntries(state, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in
                            
                        if let valueKey = valueKey, let _ = data[_id_delete] {
                            return removeValueInteractive(valueKey)
                        }
                        
                        let street1 = data[_id_street1]?.stringValue ?? ""
                        let street2 = data[_id_street2]?.stringValue ?? ""
                        let city = data[_id_city]?.stringValue ?? ""
                        let region = data[_id_region]?.stringValue ?? ""
                        let countryCode = data[_id_country]?.stringValue ?? ""
                        let postcode = data[_id_postcode]?.stringValue ?? ""
                        
                        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                        if street1.isEmpty {
                            fails[_id_street1] = .shake
                        }
                        if countryCode.isEmpty {
                            fails[_id_country] = .shake
                        }
                        if city.isEmpty {
                            fails[_id_city] = .shake
                        }
                        if region.isEmpty {
                            fails[_id_region] = .shake
                        }
                        if postcode.isEmpty {
                            fails[_id_postcode] = .shake
                        }
                        
                        var fileIndex: Int = 0
                        var verifiedDocuments:[SecureIdVerificationDocumentReference] = []
                        while data[InputDataIdentifier("_file_\(fileIndex)")] != nil {
                            let identifier = InputDataIdentifier("_file_\(fileIndex)")
                            let value = data[identifier]!.secureIdDocument!
                            switch value {
                            case let .remote(reference):
                                verifiedDocuments.append(.remote(reference))
                            case let .local(local):
                                switch local.state {
                                case let .uploaded(file):
                                    verifiedDocuments.append(.uploaded(file))
                                case .uploading:
                                    fails[identifier] = .shake
                                }
                                
                            }
                            fileIndex += 1
                        }
                        
                        
                        if !fails.isEmpty {
                            return .fail(.fields(fails))
                        }
                    
                        var values:[SecureIdValue] = []
                        if let relative = relative {
                            switch relative {
                            case .bankStatement:
                                values.append(SecureIdValue.bankStatement(SecureIdBankStatementValue(verificationDocuments: verifiedDocuments)))
                            case .rentalAgreement:
                                values.append(SecureIdValue.rentalAgreement(SecureIdRentalAgreementValue(verificationDocuments: verifiedDocuments)))
                            case .utilityBill:
                                values.append(SecureIdValue.utilityBill(SecureIdUtilityBillValue(verificationDocuments: verifiedDocuments)))
                            default:
                                break
                            }
                        }
                        values.append(SecureIdValue.address(SecureIdAddressValue(street1: street1, street2: street2, city: city, region: region, countryCode: countryCode, postcode: postcode)))
                        
                        return proccessValue(values)
                    }, updateDatas: { data in
                        updateState { current in
                            return current.withUpdatedAddressState(AddressIntermediateState.init(street1: data[_id_street1]!, street2: data[_id_street2]!, city: data[_id_city]!, region: data[_id_region]!, countryCode: data[_id_country]!, postcode: data[_id_postcode]!))
                        }
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedAddressState(nil).withUpdatedValues(current.values)
                        }
                    }))
                }
                
                if !relative.isEmpty {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormField>] = relative.map({ValuesSelectorValue(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(field, selected.value)
                    }), for: mainWindow)
                } else {
                    push(field, nil)
                }
               
                
            case .personalDetails:
                
                let push:(SecureIdRequestedFormField, SecureIdRequestedFormField?) ->Void = { field, relative in
                    presentController(InputDataController(account, dataSignal: state.get() |> map { state in
                        return identityEntries(state, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in
                        if let valueKey = valueKey, let _ = data[_id_delete] {
                            return removeValueInteractive(valueKey)
                        }
                        
                        let firstName = data[_id_name]?.stringValue ?? ""
                        let lastName = data[_id_surname]?.stringValue ?? ""
                        let birthday = data[_id_birthday]?.secureIdDate
                        let countryCode = data[_id_country]?.stringValue ?? ""
                        let gender = data[_id_gender]?.gender
                    
                    
                        let issueDate = data[_id_issue_date]?.secureIdDate
                        let expiryDate = data[_id_expire_date]?.secureIdDate
                        
                        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                        if firstName.isEmpty {
                            fails[_id_name] = .shake
                        }
                        if lastName.isEmpty {
                            fails[_id_surname] = .shake
                        }
                        if countryCode.isEmpty {
                            fails[_id_country] = .shake
                        }
                        if gender == nil {
                            fails[_id_gender] = .shake
                        }
                        if birthday == nil {
                            fails[_id_birthday] = .shake
                        }
                        if issueDate == nil, relative != nil {
                            fails[_id_issue_date] = .shake
                        }
                        
                        var fileIndex: Int = 0
                        var verifiedDocuments:[SecureIdVerificationDocumentReference] = []
                        while data[InputDataIdentifier("_file_\(fileIndex)")] != nil {
                            let identifier = InputDataIdentifier("_file_\(fileIndex)")
                            let value = data[identifier]!.secureIdDocument!
                            switch value {
                            case let .remote(reference):
                                verifiedDocuments.append(.remote(reference))
                            case let .local(local):
                                switch local.state {
                                case let .uploaded(file):
                                    verifiedDocuments.append(.uploaded(file))
                                case .uploading:
                                    fails[identifier] = .shake
                                }
                                
                            }
                            fileIndex += 1
                        }
                        
                        
                        if !fails.isEmpty {
                            return .fail(.fields(fails))
                        }
                        
                        let _birthday = birthday!
                        let _gender = gender!
                        
                        var values: [SecureIdValue] = []
                        
                        values.append(SecureIdValue.personalDetails(SecureIdPersonalDetailsValue(firstName: firstName, lastName: lastName, birthdate: _birthday, countryCode: countryCode, gender: _gender)))
                        
                        if let relative = relative {
                            let _issueDate = issueDate!
                            switch relative.valueKey {
                            case .idCard:
                                values.append(SecureIdValue.idCard(SecureIdIDCardValue(identifier: "identifier", issueDate: _issueDate, expiryDate: expiryDate, verificationDocuments: verifiedDocuments, selfieDocument: nil)))
                            case .passport:
                                values.append(SecureIdValue.passport(SecureIdPassportValue(identifier: "identifier", issueDate: _issueDate, expiryDate: expiryDate, verificationDocuments: verifiedDocuments, selfieDocument: nil)))
                            case .driversLicense:
                                values.append(SecureIdValue.driversLicense(SecureIdDriversLicenseValue(identifier: "identifier", issueDate: _issueDate, expiryDate: expiryDate, verificationDocuments: verifiedDocuments, selfieDocument: nil)))
                            default:
                                break
                            }
                        }
                        
                        

                        return proccessValue(values)

                    }, updateDatas: { data in
                        updateState { current in
                            return current.withUpdatedDetailsState(DetailsIntermediateState(firstName: data[_id_name]!, lastName: data[_id_surname]!, birthday: data[_id_birthday]!, countryCode: data[_id_country]!, gender: data[_id_gender]!, issueDate: data[_id_issue_date], expiryDate: data[_id_expire_date]))
                        }
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedDetailsState(nil).withUpdatedValues(current.values)
                        }
                    }))
                }
                
                if !relative.isEmpty {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormField>] = relative.map({ValuesSelectorValue.init(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(field, selected.value)
                    }), for: mainWindow)
                } else {
                    push(field, nil)
                }
                

            case .email:
                if let valueKey = valueKey {
                    confirm(for: mainWindow, information: L10n.secureIdRemoveEmail, successHandler: { _ in
                        _ = removeValue(valueKey)
                    })
                } else {
                    let title = L10n.secureIdInstallEmailTitle
                    var _payload: SecureIdPrepareEmailVerificationPayload? = nil
                    var _activateEmail: String? = nil
                    let validate: ([InputDataIdentifier : InputDataValue]) -> InputDataValidation = { data in
                        let email = data[_id_email_def]?.stringValue ?? data[_id_email_new]?.stringValue
                        
                        if let code = data[_id_email_code]?.stringValue, !code.isEmpty, let payload = _payload, let activateEmail = _activateEmail {
                            return .fail(.doSomething { f in
                                if let context = _stateValue.accessContext {
                                    emailNewActivationDisposable.set(showModalProgress(signal: secureIdCommitEmailVerification(network: account.network, context: context, payload: payload, code: code) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                                        f(.fail(.fields([_id_email_new : .shake])))
                                    }, completed: {
                                        f(proccessValue([SecureIdValue.email(.init(email: activateEmail))]))
                                    }))
                                }
                            })

                        }
                        
                        if data[_id_email_def] == nil, let email = email, isValidEmail(email)  {
                            return .fail(.doSomething { parent in
                                emailNewActivationDisposable.set(showModalProgress(signal: secureIdPrepareEmailVerification(network: account.network, value: .init(email: email)), for: mainWindow).start(next: { payload in
                                    _payload = payload
                                    _activateEmail = email
                                    updateState { current in
                                        return current.withUpdatedIntermediateEmailState(EmailIntermediateState(email: email))
                                    }
                                }, error: { error in
                                    
                                }))
                                
                            })
                        }
                        
                        if let email = email, isValidEmail(email) {
                            return proccessValue([SecureIdValue.email(SecureIdEmailValue(email: email))])
                        } else {
                            if data[_id_email_def] == nil {
                                return .fail(.fields([_id_email_new : .shake]))
                            }
                        }
                        return .fail(.none)
                    }
                    presentController(InputDataController(account, dataSignal: state.get() |> map { state in
                        return emailEntries(state, updateState: updateState)
                    }, title: title, validateData: validate, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedIntermediateEmailState(nil)
                        }
                    }))
                }

            case .phone:
               
                if let valueKey = valueKey {
                    confirm(for: mainWindow, information: L10n.secureIdRemovePhoneNumber, successHandler: { _ in
                        _ = removeValue(valueKey)
                    })
                } else {
                    let title = L10n.secureIdInstallPhoneTitle
                    let validate: ([InputDataIdentifier : InputDataValue]) -> InputDataValidation = { data in
                        let phone = data[_id_phone_def]?.stringValue ?? data[_id_phone_new]?.stringValue
                        if let phone = phone, !phone.isEmpty {
                            return .fail(.doSomething { parent in
                                let result = proccessValue([SecureIdValue.phone(SecureIdPhoneValue(phone: phone))])
                                switch result {
                                case let .fail(progress):
                                    switch progress {
                                    case let .doSomething(next: f):
                                        f { result in
                                            switch result {
                                            case .success:
                                                parent(.success(.navigationBack))
                                            case .fail:
                                                phoneNewActivationDisposable.set(showModalProgress(signal: secureIdPreparePhoneVerification(network: account.network, value: SecureIdPhoneValue(phone: phone)) |> deliverOnMainQueue, for: mainWindow).start(next: { payload in
                                                    presentController(InputDataController(account, dataSignal: state.get() |> map { state in
                                                        return confirmPhoneNumberEntries(state, phoneNumber: phone, updateState: updateState)
                                                    }, title: title, validateData: { data in
                                                        return .fail(.doSomething { f in
                                                            let code = data[_id_phone_code]?.stringValue ?? ""
                                                            if code.isEmpty {
                                                                f(.fail(.fields([_id_phone_code : .shake])))
                                                                return
                                                            }
                                                            if let context = _stateValue.accessContext {
                                                                phoneNewActivationDisposable.set(showModalProgress(signal: secureIdCommitPhoneVerification(network: account.network, context: context, payload: payload, code: code) |> deliverOnMainQueue, for: mainWindow).start(next: { value in
                                                                    updateState { current in
                                                                        return current.withUpdatedValue(value)
                                                                    }
                                                                    f(.success(.navigationBack))
                                                                }, error: { error in
                                                                    f(.fail(.fields([_id_phone_code : .shake])))
                                                                }))
                                                            }
                                                        })
                                                    }))
                                                }, error: { error in
                                                    alert(for: mainWindow, info: "\(error)")
                                                }))
                                                
                                            }
                                        }
                                    default:
                                        break
                                    }
                                default:
                                    break
                                }
                            })
                        } else {
                            if data[_id_phone_def] == nil {
                                return .fail(.fields([_id_phone_new : .shake]))
                            }
                        }
                        return .fail(.none)
                    }
                    presentController(InputDataController(account, dataSignal: state.get() |> map { state in
                        return phoneNumberEntries(state, updateState: updateState)
                    }, title: title, validateData: validate, afterDisappear: {

                    }))
                }
            default:
                fatalError()
            }
            
        }, createPassword: {
            let promise:Promise<[InputDataEntry]> = Promise()
            promise.set(state.get() |> map { state in
                return createPasswordEntries(state)
            })
            let controller = InputDataController(account, dataSignal: promise.get(), title: L10n.secureIdCreatePasswordTitle, validateData: { data in
                
                let password = data[_id_c_password]!.stringValue!
                let repassword = data[_id_c_repassword]!.stringValue!
                let hint = data[_id_c_hint]!.stringValue!
                
                var emptyFields:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                if password.isEmpty {
                    emptyFields[_id_c_password] = .shake
                }
                if repassword.isEmpty {
                    emptyFields[_id_c_repassword] = .shake
                }
                
                if !emptyFields.isEmpty {
                    return .fail(.fields(emptyFields))
                }
                
                if password != repassword {
                    return .fail(.fields([_id_c_repassword : .shake]))
                }
                
                
                let updatePassword: (String, String?) -> Void = { password, email in
                    updateState { current in
                        return current.withUpdatedPassword(.password(password: password, pendingEmailPattern: email))
                    }
                    let configuration: TwoStepVerificationConfiguration
                    if let email = email {
                        configuration = .notSet(pendingEmailPattern: email)
                        
                    } else {
                        configuration = .set(hint: hint, hasRecoveryEmail: false, pendingEmailPattern: email ?? "")
                    }
                    passwordVerificationData.set(.single(configuration) |> then(updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .password(password: password, hint: hint, email: email))
                        |> mapError {_ in return}
                        |> mapToSignal { settings in
                            return twoStepVerificationConfiguration(account: account) |> map { configuration in
                                
                                switch configuration {
                                case .set:
                                    updateState { current in
                                        return current.withUpdatedPassword(settings)
                                    }
                                case .notSet:
                                    break
                                }
                                return Optional(configuration)
                            }
                    }))
                }
                
                if let email = data[_id_c_email]?.stringValue {
                    if isValidEmail(email) {
                        updatePassword(password, email)
                        return .success(.navigationBack)
                    } else {
                        
                        if email.isEmpty {
                            return .fail(.doSomething(next: { f in
                                confirm(for: mainWindow, information: L10n.twoStepAuthEmailSkipAlert, okTitle: L10n.twoStepAuthEmailSkip, successHandler: { result in
                                    updatePassword(password, nil)
                                    f(.success(.navigationBack))
                                })
                            }))
                        } else {
                            return .fail(.fields([_id_c_email : .shake]))
                        }
                        
                    }
                }
                
                return .fail(.none)
            })
            
            presentController(controller)
        }, abortVerification: {
            emailActivation.set(nil)
            
            passwordVerificationData.set(showModalProgress(signal: updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .none)
                |> mapError {_ in return}
                |> mapToSignal { _ in
                    updateState { current in
                        return current.withUpdatedPasswordSettings(nil)
                    }
                    return .single(TwoStepVerificationConfiguration.notSet(pendingEmailPattern: ""))
            }, for: mainWindow))
        }, authorize: {
            authorizeDisposable.set(showModalProgress(signal: state.get() |> take(1) |> mapError { _ in return GrantSecureIdAccessError.generic} |> mapToSignal { state -> Signal<Void, GrantSecureIdAccessError> in
                return grantSecureIdAccess(network: account.network, peerId: inAppRequest.peerId, publicKey: inAppRequest.publicKey, scope: inAppRequest.scope, opaquePayload: inAppRequest.payload, values: state.values)
            } |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                alert(for: mainWindow, info: "\(error)")
            }, completed: {
                execute(inapp: .external(link: inAppRequest.callback, false))
                closeAfterSuccessful()
            }))
        }, botPrivacy: {
            
        })
        
        
        
      
        
        let signal: Signal<TableUpdateTransition, Void> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, formValue.get() |> deliverOnPrepareQueue, passwordVerificationData.get() |> deliverOnPrepareQueue, state.get() |> deliverOnPrepareQueue, account.postbox.loadedPeerWithId(form.peerId) |> deliverOnPrepareQueue) |> map { appearance, form, passwordData, state, peer in
            
            let entries = passportEntries(encryptedForm: form.0, form: form.1, peer: peer, passwordData: passwordData, state: state).map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return prepareTransition(left: previous.swap(entries), right: entries, initialSize: initialSize.modify{$0}, arguments: arguments)
        } |> deliverOnMainQueue |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        disposable.set(signal.start(next: { [weak self] transition in
            self?.genericView.merge(with: transition)
            self?.readyOnce()
        }))
        
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    private var dismissed:Bool = false
    override func invokeNavigationBack() -> Bool {
        if !dismissed {
            confirm(for: mainWindow, information: "Do you want to stop proccess secure ID?", successHandler: { [weak self] _ in
                self?.dismissed = true
                self?.dismiss()
            })
        }
        return dismissed
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func firstResponder() -> NSResponder? {
        var responder: NSResponder? = nil
        genericView.enumerateViews { view -> Bool in
            if let view = view as? PassportInsertPasswordRowView {
                if self.window?.firstResponder == view.input.textView {
                    responder = view.input.textView
                } else {
                    responder = view.input
                }
            }
            return responder == nil
        }
        return responder
    }
    
}
