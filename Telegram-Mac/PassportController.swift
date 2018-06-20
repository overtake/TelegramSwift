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


private let _id_street1 = InputDataIdentifier("street_line1")
private let _id_street2 = InputDataIdentifier("street_line2")
private let _id_postcode = InputDataIdentifier("post_code")
private let _id_city = InputDataIdentifier("city")
private let _id_state = InputDataIdentifier("state")

private let _id_delete = InputDataIdentifier("delete")

private let _id_first_name = InputDataIdentifier("first_name")
private let _id_last_name = InputDataIdentifier("last_name")
private let _id_birthday = InputDataIdentifier("birth_date")
private let _id_issue_date = InputDataIdentifier("issue_date")
private let _id_expire_date = InputDataIdentifier("expire_date")
private let _id_identifier = InputDataIdentifier("document_no")

private let _id_country = InputDataIdentifier("country_iso2")
private let _id_residence = InputDataIdentifier("residence_iso2")
private let _id_gender = InputDataIdentifier("gender")

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

private let _id_selfie = InputDataIdentifier("selfie")
private let _id_selfie_scan = InputDataIdentifier("selfie_scan")

private let _id_scan = InputDataIdentifier("scan")

private let _id_frontside = InputDataIdentifier("front_side")
private let _id_backside = InputDataIdentifier("reverse_side")

private extension SecureIdVerificationDocument {
    var errorIdentifier: InputDataIdentifier {
        switch self {
        case let .remote(file):
            let hash = file.fileHash.base64EncodedString()
            return InputDataIdentifier("file_\(hash)")
        default:
            return InputDataIdentifier("\(arc4random())")
        }
    }
}


private let cManager: CountryManager = CountryManager()

private struct EditSettingsValues {
    let values:[SecureIdValue]
    func hasValue(_ relative: SecureIdRequestedFormField) -> Bool {
        return values.contains(where: {$0.key == relative.valueKey})
    }
}

private final class PassportArguments {
    let account: Account
    let checkPassword:((String, ()->Void))->Void
    let requestField:(SecureIdRequestedFormField,  SecureIdValue?, SecureIdValue?, [SecureIdRequestedFormField], EditSettingsValues?)->Void
    let createPassword: ()->Void
    let abortVerification: ()-> Void
    let authorize:()->Void
    let botPrivacy:()->Void
    let forgotPassword:()->Void
    let deletePassport:()->Void
    init(account: Account, checkPassword:@escaping((String, ()->Void))->Void, requestField:@escaping(SecureIdRequestedFormField, SecureIdValue?, SecureIdValue?, [SecureIdRequestedFormField], EditSettingsValues?)->Void, createPassword: @escaping()->Void, abortVerification: @escaping()->Void, authorize: @escaping()->Void, botPrivacy:@escaping()->Void, forgotPassword: @escaping()->Void, deletePassport:@escaping()->Void) {
        self.account = account
        self.checkPassword = checkPassword
        self.requestField = requestField
        self.createPassword = createPassword
        self.abortVerification = abortVerification
        self.botPrivacy = botPrivacy
        self.authorize = authorize
        self.forgotPassword = forgotPassword
        self.deletePassport = deletePassport
    }
}



private enum PassportEntryId : Hashable {
    case header
    case loading
    case sectionId(Int32)
    case emptyFieldId(SecureIdRequestedFormField)
    case filledFieldId(SecureIdRequestedFormField)
    case savedFieldId(SecureIdValueKey)
    case description(Int32)
    case accept
    case requestPassword
    case createPassword
    case deletePassport
    case settingsHeader
    var hashValue: Int {
        return 0
    }
}

private let scansLimit: Int = 20

private struct FieldDescription : Equatable {
    let text: String
    let isError: Bool
    init(text: String, isError: Bool = false) {
        self.text = text
        self.isError = isError
    }
}

private enum PassportEntry : TableItemListNodeEntry {
    case header(sectionId: Int32, index: Int32, requestedFields: [SecureIdRequestedFormField], peer: Peer)
    case accept(sectionId: Int32, index: Int32, enabled: Bool)
    case emptyField(sectionId: Int32, index: Int32, fieldType: SecureIdRequestedFormField, relative: [SecureIdRequestedFormField])
    case filledField(sectionId: Int32, index: Int32, fieldType: SecureIdRequestedFormField, relative: [SecureIdRequestedFormField], description: FieldDescription, value: SecureIdValue, relativeValue: SecureIdValue?)
    case savedField(sectionId: Int32, index: Int32, valueType: SecureIdValueKey, relative: [SecureIdValueKey], relativeValues: [SecureIdValue], title: String, description: String)
    case description(sectionId: Int32, index: Int32, text: String)
    case settingsHeader(sectionId: Int32, index: Int32)
    case requestPassword(sectionId: Int32, index: Int32, hasRecoveryEmail: Bool, isSettings: Bool)
    case createPassword(sectionId: Int32, index: Int32, peer: Peer)
    case loading
    case deletePassport(sectionId: Int32, index: Int32)
    case sectionId(Int32)
    
    var stableId: PassportEntryId {
        switch self {
        case .header:
            return .header
        case let .emptyField(_, _, fieldType, _):
            return .emptyFieldId(fieldType)
        case let .filledField(_, _, fieldType, _, _, _, _):
            return .filledFieldId(fieldType)
        case let .savedField(_, _, type, _, _, _, _):
            return .savedFieldId(type)
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
        case .deletePassport:
            return .deletePassport
        case .settingsHeader:
            return .settingsHeader
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
        case let .filledField(section, index, _, _, _, _, _):
            return (section * 1000) + index
        case let .savedField(section, index, _, _, _, _, _):
            return (section * 1000) + index
        case let .description(section, index, _):
            return (section * 1000) + index
        case let .requestPassword(section, index, _, _):
            return (section * 1000) + index
        case let .createPassword(section, index, _):
            return (section * 1000) + index
        case let .deletePassport(section, index):
            return (section * 1000) + index
        case let .settingsHeader(section, index):
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
                arguments.requestField(fieldType, nil, nil, relative, nil)
            })
        case let .accept(_, _, enabled):
            return PassportAcceptRowItem(initialSize, stableId: stableId, enabled: enabled, action: {
                arguments.authorize()
            })
        case let .filledField(_, _, fieldType, relative, description, value, relativeValue):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: fieldType.rawValue, description: description.text, descTextColor: description.isError ? theme.colors.redUI : theme.colors.grayText, type: .selectable(!description.isError), action: {
                arguments.requestField(fieldType, value, relativeValue, relative, nil)
            })
        case let .savedField(_, _, fieldType, relative, relativeValues, title, description):
            
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, description: description, type: .next, action: {
                arguments.requestField(fieldType.requestFieldType, relativeValues.first(where: {$0.key == fieldType}), nil, relative.map({$0.requestFieldType}), EditSettingsValues(values: relativeValues))
                    //SecureIdRequestedFormField,  SecureIdValue?, SecureIdValue?, [SecureIdRequestedFormField]
            })
        case .requestPassword(_, _, let hasRecoveryEmail, let isSettings):
            return PassportInsertPasswordItem(initialSize, stableId: stableId, checkPasswordAction: arguments.checkPassword, forgotPassword: arguments.forgotPassword, hasRecoveryEmail: hasRecoveryEmail, isSettings: isSettings)
        case .createPassword(_, _, let peer):
            return PassportTwoStepVerificationIntroItem(initialSize, stableId: stableId, peer: peer, action: arguments.createPassword)
        case let .description(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: .markdown(text, linkHandler: { link in
                switch link {
                case "abortVerification":
                    arguments.abortVerification()
                case "_applyPolicy_":
                    arguments.botPrivacy()
                default:
                    break
                }
            }))
        case .deletePassport:
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: L10n.secureIdDeletePassport, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.redUI), type: .none, action: {
                arguments.deletePassport()
            })
        case .settingsHeader:
            return PassportSettingsHeaderItem(initialSize, stableId: stableId)
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
    case let .filledField(sectionId, index, fieldType, lhsRelative, description, lhsValue, lhsRelativeValue):
        if case .filledField(sectionId, index, fieldType, let rhsRelative, description, let rhsValue, let rhsRelativeValue) = rhs {
            return lhsValue.isSame(of: rhsValue) && lhsRelative == rhsRelative && lhsRelativeValue == rhsRelativeValue
        } else {
            return false
        }
    case let .savedField(sectionId, index, fieldType, relative, relativeValues, title, description):
        if case .savedField(sectionId, index, fieldType, relative, relativeValues, title, description) = rhs {
            return true
        } else {
            return false
        }
    case let .description(sectionId, index, text):
        if case .description(sectionId, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .requestPassword(sectionId, index, hasRecoveryEmail, isSettings):
        if case .requestPassword(sectionId, index, hasRecoveryEmail, isSettings) = rhs {
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
    case let .deletePassport(sectionId, index):
        if case .deletePassport(sectionId, index) = rhs {
            return true
        } else {
            return false
        }
    case let .settingsHeader(sectionId, index):
        if case .settingsHeader(sectionId, index) = rhs {
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
    case let .sectionId(id):
        if case .sectionId(id) = rhs {
            return true
        } else {
            return false
        }
    }
}

private func passportEntries(encryptedForm: EncryptedSecureIdForm?, form: SecureIdForm?, peer: Peer?, passwordData: TwoStepVerificationConfiguration?, state: PassportState) -> ([PassportEntry], Bool) {
    var entries:[PassportEntry] = []
    
    var enabled: Bool = false
    
    
    if let _ = passwordData {
        var sectionId: Int32 = 0
        var index: Int32 = 0
        
        if state.viewState == .settings {
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            let pdKeys:[SecureIdValueKey] = [.personalDetails, .idCard, .passport, .driversLicense, .internalPassport]
            let pdValues:[SecureIdValue] = state.values.map{$0.value}.filter{pdKeys.contains($0.key)}
            let pdDesc = pdValues.map({$0.key.requestFieldType.rawValue}).joined(separator: ", ")
            entries.append(.savedField(sectionId: sectionId, index: index, valueType: .personalDetails, relative: pdKeys, relativeValues: pdValues, title: L10n.secureIdIdentityDocument, description: pdDesc.isEmpty ? L10n.secureIdRequestPermissionIdentityEmpty : pdDesc))
            index += 1
            
            let aKeys:[SecureIdValueKey] = [.address, .rentalAgreement, .utilityBill, .bankStatement, .passportRegistration, .temporaryRegistration]
            //
            let aValues:[SecureIdValue] = state.values.map{$0.value}.filter{aKeys.contains($0.key)}
            let aDesc = aValues.map({$0.key.requestFieldType.rawValue}).joined(separator: ", ")
            entries.append(.savedField(sectionId: sectionId, index: index, valueType: .address, relative: aKeys, relativeValues: aValues, title: L10n.secureIdResidentialAddress, description:  aDesc.isEmpty ? L10n.secureIdRequestPermissionAddressEmpty : aDesc))
            index += 1
            
            var pValue: String? = nil
            var eValue: String? = nil
            
            if let value = state.values.filter({$0.value.key == .phone}).first {
                switch value.value {
                case let .phone(value):
                    pValue = formatPhoneNumber(value.phone)
                default:
                    break
                }
            }
            if let value = state.values.filter({$0.value.key == .email}).first {
                switch value.value {
                case let .email(value):
                    eValue = value.email
                default:
                    break
                }
            }
            
            entries.append(.savedField(sectionId: sectionId, index: index, valueType: .phone, relative: [], relativeValues: state.values.filter{$0.value.key == .phone}.map {$0.value}, title: L10n.secureIdPhoneNumber, description: pValue ?? L10n.secureIdRequestPermissionPhoneEmpty))
            index += 1
            
            
            entries.append(.savedField(sectionId: sectionId, index: index, valueType: .email, relative: [], relativeValues: state.values.filter{$0.value.key == .email}.map {$0.value}, title: L10n.secureIdEmail, description: eValue ?? L10n.secureIdRequestPermissionEmailEmpty))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            if !state.values.isEmpty {
                entries.append(.deletePassport(sectionId: sectionId, index: index))
                index += 1
            }
            
        } else if state.passwordSettings == nil {
            if let passwordData = passwordData {
                switch passwordData {
                case let .notSet(pendingEmailPattern):
                    
                    entries.append(.sectionId(sectionId))
                    sectionId += 1
                    
                    if pendingEmailPattern.isEmpty {
                        if let peer = peer {
                            entries.append(.createPassword(sectionId: sectionId, index: index, peer: peer))
                            index += 1
                        }
                    } else {
                        let emailText = L10n.twoStepAuthConfirmationText + "\n\n[\(tr(L10n.twoStepAuthConfirmationAbort))](abortVerification)"
                        entries.append(.description(sectionId: sectionId, index: index, text: emailText))
                        index += 1
                    }
                case let .set(_, hasRecoveryEmail, _):
                    
                    if let peer = peer, let form = encryptedForm {
                        entries.append(.header(sectionId: sectionId, index: index, requestedFields: form.requestedFields, peer: peer))
                        index += 1
                    }
                   
               
                    entries.append(.sectionId(sectionId))
                    sectionId += 1
                    
                    if encryptedForm == nil {
                        entries.append(.sectionId(sectionId))
                        sectionId += 1
                        entries.append(.settingsHeader(sectionId: sectionId, index: index))
                        index += 1
                        
                        entries.append(.sectionId(sectionId))
                        sectionId += 1
                        entries.append(.sectionId(sectionId))
                        sectionId += 1
                    }
                    
                    entries.append(.requestPassword(sectionId: sectionId, index: index, hasRecoveryEmail: hasRecoveryEmail, isSettings: encryptedForm == nil))
                    index += 1
                }
            }
            
        } else if let form = form, let peer = peer {
            
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
                case .rentalAgreement, .utilityBill, .bankStatement, .passportRegistration, .temporaryRegistration:
                    return true
                default:
                    return false
                }
            })
            
            let relativeIdentity:[SecureIdRequestedFormField] = form.requestedFields.filter({ value in
                switch value {
                case .passport, .driversLicense, .idCard, .internalPassport:
                    return true
                default:
                    return false
                }
            })
            
            for field in form.requestedFields {
                if let value = state.searchValue(field.valueKey) {
                    switch value {
                    case let .address(address):
                        let relative = relativeAddress.filter({state.searchValue($0.valueKey) != nil})
                        
                        let relativeValue:SecureIdValue?
                        if let first = relative.first {
                            relativeValue = state.searchValue(first.valueKey)
                        } else {
                            relativeValue = nil
                        }
                        
                        let desc: FieldDescription
                        let aErrors = state.errors[.address] ?? [:]
                        let rErrors = state.errors.filter({ key, _ in
                            return relativeAddress.map({$0.valueKey}).index(of: key) != nil
                        })
                        
                        let errorValues = Array(aErrors.values) + rErrors.map{$0.value}.map{$0.values}.reduce([], { current, value in
                            return current + Array(value)
                        })
                        
                        let errorText = errorValues.map {$0.description}.joined(separator: "\n")
                        let checkPoint = filledCount
                        if errorText.isEmpty {
                            var text = [address.street1, address.city, address.state, cManager.item(bySmallCountryName: address.countryCode)?.shortName ?? address.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                            if relative.count == 1 {
                                text = relative[0].rawValue + ", " + text
                            }
                            desc = FieldDescription(text: text)
                            if relativeAddress.isEmpty {
                                filledCount += 1
                            } else {
                                let field = relativeAddress.first { request -> Bool in
                                    return state.searchValue(request.valueKey) != nil
                                }
                                if let field = field {
                                    let value = state.searchValue(field.valueKey)!
                                    if ((field.hasSelfie && value.selfieVerificationDocument != nil) || !field.hasSelfie) && value.verificationDocuments != nil {
                                        filledCount += 1
                                    }
                                }
                            }
                        } else {
                            desc = FieldDescription(text: errorText, isError: true)
                        }
                        if checkPoint != filledCount || !errorText.isEmpty {
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: relative.isEmpty ? relativeAddress : relative, description: desc, value: value, relativeValue: relativeValue))
                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative:  relative.isEmpty ? relativeAddress : relative))
                        }
                        index += 1
                    case let .email(email):
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: [], description: FieldDescription(text: email.email), value: value, relativeValue: nil))
                        index += 1
                        filledCount += 1
                    case let .personalDetails(details):
                        let relative = relativeIdentity.filter({state.searchValue($0.valueKey) != nil})
                        
                        let relativeValue:SecureIdValue?
                        if let first = relative.first {
                            relativeValue = state.searchValue(first.valueKey)
                        } else {
                            relativeValue = nil
                        }
                        let desc: FieldDescription
                        
                        let pdErrors = state.errors[.personalDetails] ?? [:]
                        let rErrors = state.errors.filter({ key, _ in
                            return relativeIdentity.map({$0.valueKey}).index(of: key) != nil
                        })
                        
                        let errorValues = Array(pdErrors.values) + rErrors.map{$0.value}.map{$0.values}.reduce([], { current, value in
                            return current + Array(value)
                        })
                        
                        let errorText = errorValues.map {$0.description}.joined(separator: "\n")
                        let checkPoint = filledCount
                        
                        if errorText.isEmpty {
                            
                            var text = [details.firstName + " " + details.lastName, details.gender.stringValue, details.birthdate.stringValue, cManager.item(bySmallCountryName: details.countryCode)?.shortName ?? details.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                            if relative.count == 1 {
                                text = relative[0].rawValue + ", " + text
                            }
                            desc = FieldDescription(text: text)

                            if relativeIdentity.isEmpty {
                                filledCount += 1
                            } else {
                                let field = relativeIdentity.first { request -> Bool in
                                    return state.searchValue(request.valueKey) != nil
                                }
                                if let field = field {
                                    let value = state.searchValue(field.valueKey)!
                                    if ((field.hasSelfie && value.selfieVerificationDocument != nil) || !field.hasSelfie) && value.frontSideVerificationDocument != nil && (!field.hasBacksideDocument || value.backSideVerificationDocument != nil) {
                                        filledCount += 1
                                    }
                                }
                            }
                        } else {
                            desc = FieldDescription(text: errorText, isError: true)
                        }
                        if checkPoint != filledCount || !errorText.isEmpty {
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: relative.isEmpty ? relativeIdentity : relative, description: desc, value: value, relativeValue: relativeValue))
                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: field, relative: relative.isEmpty ? relativeIdentity : relative))
                        }
                        index += 1
                    case let .phone(phone):
                        entries.append(.filledField(sectionId: sectionId, index: index, fieldType: field, relative: [], description: FieldDescription(text: formatPhoneNumber(phone.phone)), value: value, relativeValue: nil))
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
            let policyText = encryptedForm?.termsUrl != nil ? L10n.secureIdAcceptPolicy("@\(peer.addressName ?? "")") : L10n.secureIdAcceptHelp("@\(peer.addressName ?? "")", "@\(peer.addressName ?? "")")
            entries.append(.description(sectionId: sectionId, index: index, text: policyText))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            enabled = filledCount == form.requestedFields.count - relativeAddress.count - relativeIdentity.count
            
           // entries.append(.accept(sectionId: sectionId, index: index, enabled: filledCount == form.requestedFields.count - relativeAddress.count - relativeIdentity.count))
           // index += 1
        }
       
    } else {
        entries.append(.loading)
    }
    
    return (entries, enabled)
}

fileprivate func prepareTransition(left:[AppearanceWrapperEntry<PassportEntry>], right: [AppearanceWrapperEntry<PassportEntry>], initialSize:NSSize, arguments: PassportArguments) -> TableUpdateTransition {
    let (removed, inserted, updated) = proccessEntriesWithoutReverse(left, right: right) { entry -> TableRowItem in
        return entry.entry.item(arguments, initialSize: initialSize)
    }
    return TableUpdateTransition(deleted: removed, inserted: inserted, updated: updated, animated: true)
}

private final class EmailIntermediateState : Equatable {
    let email: String
    let length: Int32
    init(email: String, length: Int32) {
        self.email = email
        self.length = length
    }
}
private func ==(lhs: EmailIntermediateState, rhs: EmailIntermediateState) -> Bool {
    return lhs.email == rhs.email && lhs.length == rhs.length
}

private final class DetailsIntermediateState : Equatable {
    let firstName: InputDataValue?
    let lastName: InputDataValue?
    let birthday: InputDataValue?
    let citizenship: InputDataValue?
    let residence: InputDataValue?
    let gender: InputDataValue?
    let expiryDate: InputDataValue?
    let identifier: InputDataValue?
    init(firstName: InputDataValue?, lastName: InputDataValue?, birthday: InputDataValue?, citizenship: InputDataValue?, residence: InputDataValue?, gender: InputDataValue?, expiryDate: InputDataValue?, identifier: InputDataValue?) {
        self.firstName = firstName
        self.lastName = lastName
        self.birthday = birthday
        self.citizenship = citizenship
        self.residence = residence
        self.gender = gender
        self.expiryDate = expiryDate
        self.identifier = identifier
    }
    
    convenience init(_ data: [InputDataIdentifier : InputDataValue]) {
        self.init(firstName: data[_id_first_name], lastName: data[_id_last_name], birthday: data[_id_birthday], citizenship: data[_id_country], residence: data[_id_residence], gender: data[_id_gender], expiryDate: data[_id_expire_date], identifier: data[_id_identifier])
    }
    
    fileprivate func validateErrors(currentState: DetailsIntermediateState, errors:[InputDataIdentifier : InputDataValueError]?) -> [InputDataIdentifier : InputDataValidationFailAction] {
        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
        
        if errors?[_id_first_name] != nil, currentState.firstName == firstName {
            fails[_id_first_name] = .shake
        }
        if errors?[_id_last_name] != nil, currentState.lastName == lastName {
            fails[_id_last_name] = .shake
        }
        if errors?[_id_birthday] != nil, currentState.birthday == birthday {
            fails[_id_birthday] = .shake
        }
        if errors?[_id_country] != nil, currentState.citizenship == citizenship {
            fails[_id_country] = .shake
        }
        if errors?[_id_residence] != nil, currentState.residence == residence {
            fails[_id_residence] = .shake
        }
        if errors?[_id_gender] != nil, currentState.gender == gender {
            fails[_id_gender] = .shake
        }
        if errors?[_id_expire_date] != nil, currentState.expiryDate == expiryDate {
            fails[_id_expire_date] = .shake
        }
        if errors?[_id_identifier] != nil, currentState.identifier == identifier {
            fails[_id_identifier] = .shake
        }
        return fails
    }
}

private func ==(lhs: DetailsIntermediateState, rhs: DetailsIntermediateState) -> Bool {
    return lhs.firstName == rhs.firstName && lhs.lastName == rhs.lastName && lhs.birthday == rhs.birthday && lhs.residence == rhs.residence && lhs.citizenship == rhs.citizenship && lhs.gender == rhs.gender && lhs.expiryDate == rhs.expiryDate && lhs.identifier == rhs.identifier
}

private final class AddressIntermediateState : Equatable {
    let street1: InputDataValue?
    let street2: InputDataValue?
    let city: InputDataValue?
    let state: InputDataValue?
    let countryCode: InputDataValue?
    let postcode: InputDataValue?
    
    init(street1: InputDataValue?, street2: InputDataValue?, city: InputDataValue?, state: InputDataValue?, countryCode: InputDataValue?, postcode: InputDataValue?) {
        self.street1 = street1
        self.street2 = street2
        self.city = city
        self.state = state
        self.countryCode = countryCode
        self.postcode = postcode
    }
    
    convenience init(_ data: [InputDataIdentifier : InputDataValue]) {
        self.init(street1: data[_id_street1], street2: data[_id_street2], city: data[_id_city], state: data[_id_state], countryCode: data[_id_country], postcode: data[_id_postcode])
    }
    
    fileprivate func validateErrors(currentState: AddressIntermediateState, errors:[InputDataIdentifier : InputDataValueError]?) -> [InputDataIdentifier : InputDataValidationFailAction] {
        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
        
        if errors?[_id_street1] != nil, currentState.street1 == street1 {
            fails[_id_street1] = .shake
        }
        if errors?[_id_street2] != nil, currentState.street2 == street2 {
            fails[_id_street2] = .shake
        }
        if errors?[_id_state] != nil, currentState.state == state {
            fails[_id_state] = .shake
        }
        if errors?[_id_city] != nil, currentState.city == city {
            fails[_id_city] = .shake
        }
        if errors?[_id_country] != nil, currentState.countryCode == countryCode {
            fails[_id_country] = .shake
        }
        if errors?[_id_postcode] != nil, currentState.postcode == postcode {
            fails[_id_postcode] = .shake
        }
        return fails
    }
}

private func ==(lhs: AddressIntermediateState, rhs: AddressIntermediateState) -> Bool {
    return lhs.street1 == rhs.street1 && lhs.street2 == rhs.street2 && lhs.city == rhs.city && lhs.state == rhs.state && lhs.countryCode == rhs.countryCode && lhs.postcode == rhs.postcode
}

private enum PassportViewState {
    case plain
    case settings
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
    
    let errors:[SecureIdValueKey: [InputDataIdentifier : InputDataValueError]]
    
    let selfies:[SecureIdValueKey : SecureIdVerificationDocument]
    let frontSideFile: [SecureIdValueKey : SecureIdVerificationDocument]
    let backSideFile: [SecureIdValueKey : SecureIdVerificationDocument]
    
    let viewState: PassportViewState
    
    init(account: Account, peer: Peer, viewState: PassportViewState, errors: [SecureIdValueKey: [InputDataIdentifier : InputDataValueError]] = [:], passwordSettings:TwoStepVerificationSettings? = nil, password: UpdateTwoStepVerificationPasswordResult? = nil, values: [SecureIdValueWithContext] = [], accessContext: SecureIdAccessContext? = nil, verifyDocumentContext: SecureIdVerificationDocumentsContext? = nil, files: [SecureIdValueKey : [SecureIdVerificationDocument]] = [:], emailIntermediateState: EmailIntermediateState? = nil, detailsIntermediateState: DetailsIntermediateState? = nil, addressIntermediateState: AddressIntermediateState? = nil, selfies: [SecureIdValueKey : SecureIdVerificationDocument] = [:], frontSideFile: [SecureIdValueKey : SecureIdVerificationDocument] = [:], backSideFile: [SecureIdValueKey : SecureIdVerificationDocument] = [:]) {
        self.account = account
        self.peer = peer
        self.errors = errors
        self.passwordSettings = passwordSettings
        self.password = password
        self.values = values
        self.viewState = viewState
        
        self.accessContext = accessContext
        self.verifyDocumentContext = verifyDocumentContext
        self.files = files
        self.emailIntermediateState = emailIntermediateState
        self.detailsIntermediateState = detailsIntermediateState
        self.addressIntermediateState = addressIntermediateState
        self.selfies = selfies
        self.frontSideFile = frontSideFile
        self.backSideFile = backSideFile
        self.verifyDocumentContext?.stateUpdated(files.reduce(Array(selfies.values) + Array(frontSideFile.values) + Array(backSideFile.values), { (current, value) -> [SecureIdVerificationDocument] in
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
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedPasswordSettings(_ settings: TwoStepVerificationSettings?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: settings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
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
        
        for (key, _) in self.files {
            let index = values.index { v -> Bool in
                return v.value.key == key
            }
            if index == nil {
                files[key] = []
            }
        }
        
        var selfies = self.selfies
        if let selfie = value.value.selfieVerificationDocument {
            switch selfie {
            case let .remote(file):
                selfies[value.value.key] = .remote(file)
            default:
                selfies[value.value.key] = nil
            }
        }
        
        var frontSideFile = self.frontSideFile
        if let frontSide = value.value.frontSideVerificationDocument {
            switch frontSide {
            case let .remote(file):
                frontSideFile[value.value.key] = .remote(file)
            default:
                frontSideFile[value.value.key] = nil
            }
        }
        
        var backSideFile = self.backSideFile
        if let backSide = value.value.backSideVerificationDocument {
            switch backSide {
            case let .remote(file):
                backSideFile[value.value.key] = .remote(file)
            default:
                backSideFile[value.value.key] = nil
            }
        }
        
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, frontSideFile: frontSideFile, backSideFile: backSideFile)
    }
    
    func withRemovedValue(_ key: SecureIdValueKey) -> PassportState {
        var values = self.values
        let index = values.index { v -> Bool in
            return v.value.key == key
        }
        if let index = index {
            values.remove(at: index)
        }
        var files = self.files
        files.removeValue(forKey: key)
        
        var selfies = self.selfies
        selfies.removeValue(forKey: key)
        
        var frontSideFile = self.frontSideFile
        frontSideFile.removeValue(forKey: key)
        
        var backSideFile = self.backSideFile
        backSideFile.removeValue(forKey: key)
        
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, frontSideFile: frontSideFile, backSideFile: backSideFile)
    }
    
    func withUpdatedAccessContext(_ accessContext: SecureIdAccessContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedVerifyDocumentContext(_ verifyDocumentContext: SecureIdVerificationDocumentsContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
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
        var selfies = self.selfies
        loop: for (key, value) in self.selfies {
            if value.id.hashValue == id {
                switch value {
                case var .local(document):
                    document.state = state
                    selfies[key] = .local(document)
                    break loop
                default:
                    break
                }
            }
        }
        var frontSideFile = self.frontSideFile
        loop: for (key, value) in self.frontSideFile {
            if value.id.hashValue == id {
                switch value {
                case var .local(document):
                    document.state = state
                    frontSideFile[key] = .local(document)
                    break loop
                default:
                    break
                }
            }
        }
        var backSideFile = self.backSideFile
        loop: for (key, value) in self.backSideFile {
            if value.id.hashValue == id {
                switch value {
                case var .local(document):
                    document.state = state
                    backSideFile[key] = .local(document)
                    break loop
                default:
                    break
                }
            }
        }
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, frontSideFile: frontSideFile, backSideFile: backSideFile)
    }
    
    func withAppendFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var current = self.files[valueKey] ?? []
        current.append(contentsOf: files)
        var dictionary = self.files
        dictionary[valueKey] = current
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var dictionary = self.files
        dictionary[valueKey] = files
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
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
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withRemovedValues() -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: [], accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedIntermediateEmailState(_ emailIntermediateState: EmailIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedDetailsState(_ detailsIntermediateState: DetailsIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    func withUpdatedAddressState(_ addressState: AddressIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    func withUpdatedViewState(_ viewState: PassportViewState) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    func withUpdatedSelfie(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var selfies = self.selfies
        if let value = value {
            selfies[key] = value
        } else {
            selfies.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedFrontSide(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var frontSideFile = self.frontSideFile
        if let value = value {
            frontSideFile[key] = value
        } else {
            frontSideFile.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, frontSideFile: frontSideFile, backSideFile: self.backSideFile)
    }
    
    func withUpdatedBackSide(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var backSideFile = self.backSideFile
        if let value = value {
            backSideFile[key] = value
        } else {
            backSideFile.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: backSideFile)
    }
    
    func errors(for key: SecureIdValueKey) -> [InputDataIdentifier : InputDataValueError] {
        switch key {
        case .address:
            var aErrors = errors[key] ?? [:]
            let rKeys:[SecureIdValueKey] = [.rentalAgreement, .utilityBill, .bankStatement]
            for rKey in rKeys {
                if let rErrors = errors[rKey] {
                    for(key, value) in rErrors {
                        aErrors[key] = value
                    }
                }
            }
            return aErrors
        case .personalDetails:
            var aErrors = errors[key] ?? [:]
            let rKeys:[SecureIdValueKey] = [.passport, .driversLicense, .idCard]
            for rKey in rKeys {
                if let rErrors = errors[rKey] {
                    for(key, value) in rErrors {
                        aErrors[key] = value
                    }
                }
            }
            return aErrors
        default:
            return errors[key] ?? [:]
        }
    }
    
    func withRemovedErrors(for key: SecureIdValueKey) -> PassportState {
        var errors = self.errors
        switch key {
        case .address:
            errors.removeValue(forKey: key)
            let rKeys:[SecureIdValueKey] = [.rentalAgreement, .utilityBill, .bankStatement]
            for rKey in rKeys {
                errors.removeValue(forKey: rKey)
            }
        case .personalDetails:
            errors.removeValue(forKey: key)
            let rKeys:[SecureIdValueKey] = [.passport, .driversLicense, .idCard]
            for rKey in rKeys {
                errors.removeValue(forKey: rKey)
            }
        default:
            errors.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
    }
    func withUpdatedErrors(_ errors: [SecureIdValueKey: [InputDataIdentifier : InputDataValueError]]) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile)
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
    
    if lhs.selfies.count != rhs.selfies.count {
        return false
    } else {
        for (lhsKey, lhsValue) in lhs.selfies {
            let rhsValue = rhs.selfies[lhsKey]
            if let rhsValue = rhsValue {
                if !lhsValue.isEqual(to: rhsValue) {
                    return false
                }
                
            } else {
                return false
            }
        }
    }
    
    
    return lhs.passwordSettings?.email == rhs.passwordSettings?.email && lhs.password == rhs.password && lhs.values == rhs.values && (lhs.accessContext == nil && rhs.accessContext == nil) && lhs.emailIntermediateState == rhs.emailIntermediateState && lhs.detailsIntermediateState == rhs.detailsIntermediateState && lhs.addressIntermediateState == rhs.addressIntermediateState && lhs.errors == rhs.errors && lhs.viewState == rhs.viewState
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
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_c_password, mode: .secure, placeholder: L10n.secureIdCreatePasswordPasswordPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordPasswordInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value:  .string(""), error: nil, identifier: _id_c_repassword, mode: .secure, placeholder: "", inputPlaceholder: L10n.secureIdCreatePasswordRePasswordInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1

    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordDescription, color: theme.colors.grayText, detectBold: true))
    index += 1

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordHintHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_c_hint, mode: .plain, placeholder: L10n.secureIdCreatePasswordHintPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordHintInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordEmailHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_c_email, mode: .plain, placeholder: L10n.secureIdCreatePasswordEmailPlaceholder, inputPlaceholder: L10n.secureIdCreatePasswordEmailInputPlaceholder, filter: nonFilter, limit: 255))
    index += 1
    
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdCreatePasswordEmailDescription, color: theme.colors.grayText, detectBold: true))
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
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_email_code, mode: .plain, placeholder: L10n.secureIdEmailActivateCodePlaceholder, inputPlaceholder: L10n.secureIdEmailActivateCodeInputPlaceholder, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: Int32(email.length)))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdEmailActivateDescription(email), color: theme.colors.grayText, detectBold: true))
        index += 1
        
        return entries
        
    } else  if let email = state.passwordSettings?.email, !email.isEmpty {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(email), error: nil, identifier: _id_email_def, name: L10n.secureIdEmailUseSame(email), color: theme.colors.blueUI, icon: nil, type: .next))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_email_new, mode: .plain, placeholder: L10n.secureIdEmailEmailPlaceholder, inputPlaceholder: L10n.secureIdEmailEmailInputPlaceholder, filter: {$0}, limit: 254))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdEmailUseSameDesc, color: theme.colors.grayText, detectBold: true))
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
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(phone), error: nil, identifier: _id_phone_def, name: L10n.secureIdPhoneNumberUseSame(formatPhoneNumber(phone)), color: theme.colors.blueUI, icon: nil, type: .next))
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberUseSameDesc, color: theme.colors.grayText, detectBold: true))
        index += 1
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .string(""), identifier: _id_phone_new, equatable: nil, item: { initialSize, stableId -> TableRowItem in
        return PassportNewPhoneNumberRowItem(initialSize, stableId: stableId, action: {
            
        })
    }))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberNote, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    return entries
}

private func confirmPhoneNumberEntries( _ state: PassportState, phoneNumber: String, updateState: @escaping ((PassportState)->PassportState)->Void) -> [InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    
    
    entries.append(.sectionId(sectionId))
    sectionId += 1

    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_phone_code, mode: .plain, placeholder: L10n.secureIdPhoneNumberConfirmCodePlaceholder, inputPlaceholder: L10n.secureIdPhoneNumberConfirmCodeInputPlaceholder, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 6))
    
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdPhoneNumberConfirmCodeDesc(formatPhoneNumber(phoneNumber)), color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    return entries
}

private func addressEntries( _ state: PassportState, hasMainField: Bool, relative: SecureIdRequestedFormField?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
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

    
    let aErrors: [InputDataIdentifier : InputDataValueError]? = state.errors[.address]

    
    if hasMainField {
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdAddressHeader, color: theme.colors.grayText, detectBold: true))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.street1 ?? .string(address?.street1), error: aErrors?[_id_street1], identifier: _id_street1, mode: .plain, placeholder: L10n.secureIdAddressStreetPlaceholder, inputPlaceholder: L10n.secureIdAddressStreetInputPlaceholder, filter: nonFilter, limit: 255))
        index += 1
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.street2 ?? .string(address?.street2), error: aErrors?[_id_street2], identifier: _id_street2, mode: .plain, placeholder: "", inputPlaceholder: L10n.secureIdAddressStreet1InputPlaceholder, filter: nonFilter, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.city ?? .string(address?.city), error: aErrors?[_id_city], identifier: _id_city, mode: .plain, placeholder: L10n.secureIdAddressCityPlaceholder, inputPlaceholder: L10n.secureIdAddressCityInputPlaceholder, filter: nonFilter, limit: 255))
        index += 1
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.state ?? .string(address?.state), error: aErrors?[_id_state], identifier: _id_state, mode: .plain, placeholder: L10n.secureIdAddressRegionPlaceholder, inputPlaceholder: L10n.secureIdAddressRegionInputPlaceholder, filter: nonFilter, limit: 255))
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
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.addressIntermediateState?.countryCode ?? .string(address?.countryCode), error: aErrors?[_id_country], identifier: _id_country, placeholder: L10n.secureIdAddressCountryPlaceholder, values: countries))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.postcode ?? .string(address?.postcode), error: aErrors?[_id_postcode], identifier: _id_postcode, mode: .plain, placeholder: L10n.secureIdAddressPostcodePlaceholder, inputPlaceholder: L10n.secureIdAddressPostcodeInputPlaceholder, filter: { string in
            let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
            let lower = "abcdefghijklmnopqrstuvwxyz"
            return string.trimmingCharacters(in: CharacterSet(charactersIn: upper + lower + "0987654321" + "-").inverted)
        }, limit: 10))
        index += 1
        
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    

    
    if let relative = relative {
        let rErrors = state.errors[relative.valueKey]

        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdScansHeader, color: theme.colors.grayText, detectBold: true))
        index += 1
        
        if let scanError = rErrors?[_id_scan] {
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: scanError.description, color: theme.colors.redUI, detectBold: true))
            index += 1
        }
        
        let files = state.files[relative.valueKey] ?? []
        
        var fileIndex: Int32 = 0
        
        if let accessContext = state.accessContext {
            for file in files {
                let header = L10n.secureIdScanNumber(Int(fileIndex + 1))
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(file), identifier:  InputDataIdentifier("_file_\(fileIndex)"), equatable: InputDataEquatable(file), item: { initialSize, stableId -> TableRowItem in
                    return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: file, context: accessContext, stableId: stableId), error: rErrors?[file.errorIdentifier], header: header, removeAction: { value in
                        updateState { current in
                            return current.withRemovedFile(value, for: relative.valueKey)
                        }
                    })
                }))
                fileIndex += 1
                index += 1
            }
        }
        
        if files.count < scansLimit {
            entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_scan, placeholder: files.count > 0 ? L10n.secureIdUploadAdditionalScan : L10n.secureIdUploadScan, description: nil, icon: nil, action: {
                filePanel(with: photoExts, allowMultiple: true, for: mainWindow, completion: { files in
                    if let files = files {
                        let localFiles:[SecureIdVerificationDocument] = files.map({.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                        
                        updateState { current in
                            return current.withAppendFiles(localFiles, for: relative.valueKey)
                        }
                    }
                })
            }))
            index += 1
        }
       
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityScanDescription, color: theme.colors.grayText, detectBold: true))
        index += 1
        
    }
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    if address != nil || relativeValue != nil {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_delete, name: L10n.secureIdDeleteAddress, color: theme.colors.redUI, icon: nil, type: .none))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }

    return entries
    
}

private func identityEntries( _ state: PassportState, hasMainField: Bool, relative: SecureIdRequestedFormField?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
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
   
    let pdErrors = state.errors[.personalDetails]

    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityDocumentDetailsHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    let nameFilter:(String)->String = { text in
        let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let lower = "abcdefghijklmnopqrstuvwxyz"
        return text.trimmingCharacters(in: CharacterSet(charactersIn: upper + lower).inverted)
    }
    
    if hasMainField {
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.firstName ?? .string(personalDetails?.firstName ?? ""), error: pdErrors?[_id_first_name], identifier: _id_first_name, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderFirstName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderFirstName, filter: nameFilter, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.lastName ?? .string(personalDetails?.lastName ?? ""), error: pdErrors?[_id_last_name], identifier: _id_last_name, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderLastName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderLastName, filter: nameFilter, limit: 255))
        index += 1
        
        let genders:[ValuesSelectorValue<InputDataValue>] = [ValuesSelectorValue(localized: L10n.secureIdGenderMale, value: .gender(.male)), ValuesSelectorValue(localized: L10n.secureIdGenderFemale, value: .gender(.female))]
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.gender ?? .gender(personalDetails?.gender), error: pdErrors?[_id_gender], identifier: _id_gender, placeholder: L10n.secureIdIdentityPlaceholderGender, values: genders))
        index += 1
        
        entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.birthday ?? personalDetails?.birthdate.inputDataValue ?? .date(nil, nil, nil), error: pdErrors?[_id_birthday], identifier: _id_birthday, placeholder: L10n.secureIdIdentityPlaceholderBirthday))
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
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.citizenship ?? .string(personalDetails?.countryCode), error: pdErrors?[_id_country], identifier: _id_country, placeholder: L10n.secureIdIdentityPlaceholderCitizenship, values: countries))
        index += 1
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.residence ?? .string(personalDetails?.residenceCountryCode), error: pdErrors?[_id_residence], identifier: _id_residence, placeholder: L10n.secureIdIdentityPlaceholderResidence, values: countries))
        index += 1

    }
    
    

    

    if let relative = relative {
        let rErrors = state.errors[relative.valueKey]
        
        var title: String = ""
        var subtitle: String = ""
        switch relative {
        case .passport:
            title = L10n.secureIdIdentityPassportPlaceholder
            subtitle = L10n.secureIdIdentityPassportInputPlaceholder
        case .internalPassport:
            title = L10n.secureIdIdentityPassportPlaceholder
            subtitle = L10n.secureIdIdentityPassportInputPlaceholder
        case .idCard:
            title = L10n.secureIdIdentityCardIdPlaceholder
            subtitle = L10n.secureIdIdentityCardIdInputPlaceholder
        case .driversLicense:
            title = L10n.secureIdIdentityLicensePlaceholder
            subtitle = L10n.secureIdIdentityLicenseInputPlaceholder
        default:
            break
        }
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.identifier ?? .string(relativeValue?.identifier), error: rErrors?[_id_identifier], identifier: _id_identifier, mode: .plain, placeholder: title, inputPlaceholder: subtitle, filter: nonFilter, limit: 20))
        index += 1
        
        entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.expiryDate ?? relativeValue?.expiryDate?.inputDataValue ?? .date(nil, nil, nil), error: rErrors?[_id_expire_date], identifier: _id_expire_date, placeholder: L10n.secureIdIdentityPlaceholderExpiryDate))
        index += 1
    }

    

    if let relative = relative {
        
        entries.append(.sectionId(sectionId))
        sectionId += 1
        
        let rErrors = state.errors[relative.valueKey]
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdScansHeader, color: theme.colors.grayText, detectBold: true))
        index += 1
        
        if let scanError = rErrors?[_id_scan] {
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: scanError.description, color: theme.colors.redUI, detectBold: true))
            index += 1
        }
        if let accessContext = state.accessContext {
            let isMainNotFront: Bool = !relative.hasBacksideDocument
            if let file = state.frontSideFile[relative.valueKey] {
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(file), identifier: _id_frontside, equatable: InputDataEquatable(file), item: { initialSize, stableId -> TableRowItem in
                    return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: file, context: accessContext, stableId: stableId), error: rErrors?[_id_frontside], header: isMainNotFront ? L10n.secureIdUploadTitleMainPage : L10n.secureIdUploadTitleFrontSide, removeAction: { value in
                        updateState { current in
                            return current.withUpdatedFrontSide(nil, for: relative.valueKey)
                        }
                    })
                }))
                index += 1
            } else {
                entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_frontside, placeholder: isMainNotFront ? L10n.secureIdUploadTitleMainPage : L10n.secureIdUploadTitleFrontSide, description: relative.uploadFrontTitleText, icon: isMainNotFront ? theme.icons.passportPassport : (relative.valueKey == .driversLicense ? theme.icons.passportDriverLicense : theme.icons.passportIdCard), action: {
                    filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { files in
                        if let file = files?.first {
                            if let image = NSImage(contentsOfFile: file) {
                                let string = recognizeMRZ(image.precomposed(), nil)
                                let mrz = TGPassportMRZ.parseLines(string?.components(separatedBy: "\n"))
                               let localFile:SecureIdVerificationDocument = .local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: file, randomId: arc4random64()), state: .uploading(0)))
                                
                                updateState { current in
                                    var current = current
                                    if let mrz = mrz {
                                        if relative.isEqualToMRZ(mrz) {
                                            let expiryDate = dateFormatter.string(from: mrz.expiryDate).components(separatedBy: ".").map({Int32($0)})
                                            let birthDate = dateFormatter.string(from: mrz.birthDate).components(separatedBy: ".").map({Int32($0)})
                                            let details = DetailsIntermediateState(firstName: .string(mrz.firstName), lastName: .string(mrz.lastName), birthday: .date(birthDate[0], birthDate[1], birthDate[2]), citizenship: .string(mrz.issuingCountry), residence: current.detailsIntermediateState?.residence, gender: .gender(SecureIdGender.gender(from: mrz)), expiryDate: .date(expiryDate[0], expiryDate[1], expiryDate[2]), identifier: .string(mrz.documentNumber))
                                            current = current.withUpdatedDetailsState(details)
                                        }
                                    }
                                    return current.withUpdatedFrontSide(localFile, for: relative.valueKey)
                                }
                            }
                            
                        }
                    })
                }))
                index += 1
            }
            
            if relative.hasBacksideDocument {
                if let file = state.backSideFile[relative.valueKey] {
                    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(file), identifier: _id_backside, equatable: InputDataEquatable(file), item: { initialSize, stableId -> TableRowItem in
                        return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: file, context: accessContext, stableId: stableId), error: rErrors?[_id_backside], header: L10n.secureIdUploadTitleReverseSide, removeAction: { value in
                            updateState { current in
                                return current.withUpdatedBackSide(nil, for: relative.valueKey)
                            }
                        })
                    }))
                    index += 1
                } else {
                    entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_backside, placeholder: isMainNotFront ? L10n.secureIdUploadTitleMainPage : L10n.secureIdUploadTitleReverseSide, description: relative.uploadBackTitleText, icon: theme.icons.passportIdCardReverse, action: {
                        filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { files in
                            if let file = files?.first {
                                if let image = NSImage(contentsOfFile: file) {
                                    let string = recognizeMRZ(image.precomposed(), nil)
                                    let mrz = TGPassportMRZ.parseLines(string?.components(separatedBy: "\n"))
                                    let localFile:SecureIdVerificationDocument = .local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: file, randomId: arc4random64()), state: .uploading(0)))
                                    
                                    updateState { current in
                                        var current = current
                                        if let mrz = mrz {
                                            if relative.isEqualToMRZ(mrz) {
                                                let expiryDate = dateFormatter.string(from: mrz.expiryDate).components(separatedBy: ".").map({Int32($0)})
                                                let birthDate = dateFormatter.string(from: mrz.birthDate).components(separatedBy: ".").map({Int32($0)})
                                                let details = DetailsIntermediateState(firstName: .string(mrz.firstName), lastName: .string(mrz.lastName), birthday: .date(birthDate[0], birthDate[1], birthDate[2]), citizenship: .string(mrz.issuingCountry), residence: current.detailsIntermediateState?.residence, gender: .gender(SecureIdGender.gender(from: mrz)), expiryDate: .date(expiryDate[0], expiryDate[1], expiryDate[2]), identifier: .string(mrz.documentNumber))
                                                current = current.withUpdatedDetailsState(details)
                                            }
                                        }
                                        return current.withUpdatedBackSide(localFile, for: relative.valueKey)
                                    }
                                }
                            }
                        })
                    }))
                    index += 1
                }
            }
        }
   
        
        if relative.hasSelfie, let accessContext = state.accessContext {
            let rErrors = state.errors[relative.valueKey]
            if let selfie = state.selfies[relative.valueKey] {
                entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(selfie), identifier: _id_selfie, equatable: InputDataEquatable(selfie), item: { initialSize, stableId -> TableRowItem in
                    return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: selfie, context: accessContext, stableId: stableId), error: rErrors?[_id_selfie], header: L10n.secureIdIdentitySelfie, removeAction: { value in
                        updateState { current in
                            return current.withUpdatedSelfie(nil, for: relative.valueKey)
                        }
                    })
                }))
                index += 1
                
            } else {
                entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_selfie_scan, placeholder: L10n.secureIdIdentitySelfie, description: L10n.secureIdUploadSelfie, icon: theme.icons.passportSelfie, action: {
                    pickImage(for: mainWindow, completion: { image in
                        if let image = image {
                            _ = putToTemp(image: image).start(next: { path in
                                let localFile:SecureIdVerificationDocument = .local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: path, randomId: arc4random64()), state: .uploading(0)))
                                
                                updateState { current in
                                    return current.withUpdatedSelfie(localFile, for: relative.valueKey)
                                }
                            })
                        }
                    })
                }))
                index += 1
            }
        }
        
//        entries.append(.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityScanDescription, color: theme.colors.grayText, detectBold: true))
//        index += 1
        
    }
    

    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    if personalDetails != nil || relativeValue != nil {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_delete, name: relativeValue != nil ? L10n.secureIdDeleteIdentity : L10n.secureIdDeletePersonalDetails, color: theme.colors.redUI, icon: nil, type: .none))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }

    
    return entries
}

private func recoverEmailEntries(emailPattern: String) -> [InputDataEntry] {
    var entries: [InputDataEntry] = []
    
    var sectionId:Int32 = 0
    var index:Int32 = 0
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_email_code, mode: .plain, placeholder: L10n.secureIdEmailActivateCodePlaceholder, inputPlaceholder: L10n.secureIdEmailActivateCodeInputPlaceholder, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: 6))
    index += 1
    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdRecoverPasswordSentEmailCode(emailPattern), color: theme.colors.grayText, detectBold: false))
    index += 1
    
    return entries
}

final class PassportControllerView : View {
    let tableView: TableView = TableView()
    let authorize: PassportAcceptRowView = PassportAcceptRowView(frame: NSZeroRect)
    private var item: PassportAcceptRowItem?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(tableView)
        addSubview(authorize)
        updateLocalizationAndTheme()
        layout()
    }
    
    override func updateLocalizationAndTheme() {
        backgroundColor = theme.colors.background
    }
    
    override func layout() {
        super.layout()
        tableView.frame = NSMakeRect(0, 0, frame.width, frame.height - 80)
        authorize.frame = NSMakeRect(0, frame.height - 80, frame.width, 80)
    }
    
    func updateEnabled(_ enabled: Bool, isVisible: Bool, action: @escaping()->Void) {
        self.item = PassportAcceptRowItem(authorize.frame.size, stableId: 0, enabled: enabled, action: action)
        authorize.set(item: item!, animated: false)
        authorize.isHidden = !isVisible
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PassportController: TelegramGenericViewController<PassportControllerView> {

    private let form: EncryptedSecureIdForm?
    private let disposable = MetaDisposable()
    private let peer: Peer
    private let request: inAppSecureIdRequest?
    init(_ account: Account, _ peer: Peer, request: inAppSecureIdRequest?, _ form: EncryptedSecureIdForm?) {
        self.form = form
        self.peer = peer
        self.request = request
        super.init(account)
        
    }
    
    override var enableBack: Bool {
        return true
    }
    
    override func backSettings() -> (String, CGImage?) {
        return (form == nil ? L10n.navigationBack : L10n.navigationCancel, form == nil ? #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(theme.colors.blueIcon) : nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        window?.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
            guard let `self` = self else {return .rejected}
            
            let index = self.genericView.tableView.row(at: self.genericView.tableView.documentView!.convert(event.locationInWindow, from: nil))
            
            if index > 0, let view = self.genericView.tableView.item(at: index).view {
                if view.mouseInsideField {
                    if self.window?.firstResponder != view.firstResponder {
                        self.window?.makeFirstResponder(view.firstResponder)
                        return .invoked
                    }
                }
            }
            
            return .rejected
        }, with: self, for: .leftMouseDown)
    }
    
    override func requestUpdateRightBar() {
        rightView?.set(image: theme.icons.passportInfo)
    }
    
    private var rightView: ImageBarView?
    
    override func getRightBarViewOnce() -> BarView {
        if form == nil {
            let account = self.account
            rightView = ImageBarView(controller: self, theme.icons.passportInfo)
            rightView?.button.set(handler: { _ in
                confirm(for: mainWindow, header: L10n.secureIdInfoTitle, information: L10n.secureIdInfo, cancelTitle: "", thridTitle: L10n.secureIdInfoMore, successHandler: { result in
                    if result == .thrid {
                        openFaq(account: account)
                    }
                })
            }, for: .Click)
            
            return rightView!
        } else {
            return super.getRightBarViewOnce()
        }
       
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
        let recoverPasswordDisposable = MetaDisposable()

        actionsDisposable.add(checkPassword)
        actionsDisposable.add(authorizeDisposable)
        actionsDisposable.add(emailNewActivationDisposable)
        actionsDisposable.add(phoneNewActivationDisposable)
        actionsDisposable.add(recoverPasswordDisposable)
        
        let state:ValuePromise<PassportState> = ValuePromise(PassportState(account: account, peer: peer, viewState: .plain), ignoreRepeated: true)
        
        let stateValue:Atomic<PassportState> = Atomic(value: PassportState(account: account, peer: peer, viewState: .plain))
        
        var _stateValue: PassportState {
            return stateValue.modify({$0})
        }
        
        let updateState:((PassportState)->PassportState) -> Void = { f in
            state.set(stateValue.modify(f))
        }
        
        let closeAfterSuccessful:()->Void = { [weak self] in
            _ = self?.window?.closeInterceptor?()
        }
        
        let closeController:()->Void = { [weak self] in
            self?.navigationController?.back()
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
                                    if let encryptedForm = encryptedForm {
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
                                                    //return current
                                                    return current.withUpdatedAccessContext(context).withUpdatedPasswordSettings(settings).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                                                }
                                                formValue.set(.single((nil, form)))
                                                return Optional(config)
                                            } |> mapError {_ in return}
                                    } else {
                                        let signal = accessSecureId(network: account.network, password: password) |> mapToSignal { context in
                                            return getAllSecureIdValues(network: account.network)
                                                |> map { encryptedValues in
                                                    return decryptedAllSecureIdValues(context: context, encryptedValues: encryptedValues)
                                                }
                                                |> mapError {_ in return SecureIdAccessError.generic}
                                                |> map {($0, context)}
                                            } |> mapToSignal { values, context in
                                                return requestTwoStepVerifiationSettings(network: account.network, password: password) |> mapError {_ in return SecureIdAccessError.generic} |> map { settings in
                                                    return (values, settings, context)
                                                }
                                            } |> deliverOnMainQueue
                                        
                                        return signal |> map { values, passwordSettings, context in
                                            updateState { current in
                                                var current = current.withRemovedValues()
                                                current = values.reduce(current, { current, value -> PassportState in
                                                    return current.withUpdatedValue(value)
                                                })
                                                return current.withUpdatedViewState(.settings).withUpdatedPasswordSettings(passwordSettings).withUpdatedAccessContext(context).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                                            }
                                             return Optional(config)
                                        } |> mapError {_ in}
                                        
                                    }
                                    
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
        
        let executeCallback:(Bool) -> Void = { [weak self] success in
            self?.executeCallback(success)
        }
        
        let previous: Atomic<[AppearanceWrapperEntry<PassportEntry>]> = Atomic(value: [])
        
        
        let arguments = PassportArguments(account: account, checkPassword: { value, shake in
            if let encryptedForm = encryptedForm {
                checkPassword.set(showModalProgress(signal: accessSecureId(network: account.network, password: value) |> map { context in
                    return (decryptedSecureIdForm(context: context, form: encryptedForm), context)
                    } |> deliverOnMainQueue |> mapToSignal { (form, context) in
                        return requestTwoStepVerifiationSettings(network: account.network, password: value) |> mapError {_ in return SecureIdAccessError.generic} |> map { settings in
                            return (form, context, settings)
                        }
                    } |> deliverOnMainQueue, for: mainWindow).start(next: { form, context, settings in
                        
                        updateState { current in
                            var current = current.withRemovedValues()
                            if let form = form {
                                current = form.values.reduce(current, { current, value -> PassportState in
                                    return current.withUpdatedValue(value)
                                })
                                var errors:[SecureIdValueKey: [InputDataIdentifier : InputDataValueError]] = [:]
                                
                                for value in form.values {
                                    var cErrors = errors[value.value.key] ?? [:]
                                    
                                    for(eKey, eValue) in value.errors {
                                        switch eKey {
                                        case let .field(field):
                                            switch field {
                                            case let .address(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            case let .driversLicense(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            case let .idCard(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            case let .passport(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            case let .personalDetails(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            case let .internalPassport(f):
                                                cErrors[InputDataIdentifier(f.rawValue)] = InputDataValueError(description: eValue, target: .data)
                                            }
                                        case .files:
                                            cErrors[_id_scan] = InputDataValueError(description: eValue, target: .files)
                                        case let .file(hash):
                                            cErrors[InputDataIdentifier("file_\(hash.base64EncodedString())")] = InputDataValueError(description: eValue, target: .files)
                                        case .selfie:
                                            cErrors[_id_selfie] = InputDataValueError(description: eValue, target: .files)
                                        case .frontSide:
                                            cErrors[_id_frontside] = InputDataValueError(description: eValue, target: .files)
                                        case .backSide:
                                            cErrors[_id_backside] = InputDataValueError(description: eValue, target: .files)
                                        }
                                    }
                                    errors[value.value.key] = cErrors
                                }
                                current = current.withUpdatedErrors(errors)
                            }
                            return current.withUpdatedAccessContext(context).withUpdatedPasswordSettings(settings).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                        }
                        formValue.set(.single((nil, form)))
                    }, error: { error in
                        switch error {
                        case .secretPasswordMismatch:
                            confirm(for: mainWindow, header: L10n.telegramPassportController, information: "Something going wrong", thridTitle: "Delete All Values", successHandler: { result in
                                switch result {
                                case .basic:
                                    break
                                case .thrid:
                                    _ = showModalProgress(signal: updateTwoStepVerificationPassword(network: account.network, currentPassword: value, updatedPassword: .none) |> deliverOnMainQueue, for: mainWindow).start(next: {_ in
                                        updateState { current in
                                            return current.withUpdatedPassword(nil)
                                        }
                                        passwordVerificationData.set(.single(.notSet(pendingEmailPattern: "")))
                                    }, error: { error in
                                        
                                    })
                                }
                            })
                        case .passwordError:
                            shake()
                        case .generic:
                            shake()
                        }
                        
                    }))
            } else {
                let signal = accessSecureId(network: account.network, password: value) |> mapToSignal { context in
                    return getAllSecureIdValues(network: account.network)
                        |> map { encryptedValues in
                            return decryptedAllSecureIdValues(context: context, encryptedValues: encryptedValues)
                        }
                        |> mapError {_ in return SecureIdAccessError.generic}
                        |> map {($0, context)}
                } |> mapToSignal { values, context in
                    return requestTwoStepVerifiationSettings(network: account.network, password: value) |> mapError {_ in return SecureIdAccessError.generic} |> map { settings in
                        return (values, settings, context)
                    }
                } |> deliverOnMainQueue
                
                
                    
                checkPassword.set(showModalProgress(signal: signal, for: mainWindow).start(next: { values, passwordSettings, context in
                    
                    updateState { current in
                        var current = current.withRemovedValues()
                        current = values.reduce(current, { current, value -> PassportState in
                            return current.withUpdatedValue(value)
                        })
                        return current.withUpdatedViewState(.settings).withUpdatedPasswordSettings(passwordSettings).withUpdatedAccessContext(context).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                    }
                }, error: { error in
                   shake()
                }))
            }
        }, requestField: { field, value, relativeValue, relative, editSettings in

            let valueKey = value?.key
            let proccessValue:([SecureIdValue])->InputDataValidation = { values in
                return .fail(.doSomething(next: { f in

                    let signal: Signal<[SecureIdValueWithContext], SaveSecureIdValueError> = state.get() |> take(1) |> mapError {_ in return SaveSecureIdValueError.generic} |> mapToSignal { state in
                        if let context = state.accessContext {
                            return combineLatest(values.map({ value in
                                return saveSecureIdValue(postbox: account.postbox, network: account.network, context: context, value: value, uploadedFiles: [:])
                            }))
                        } else {
                            return .fail(.generic)
                        }
                        } |> deliverOnMainQueue

                    saveValueDisposable.set(showModalProgress(signal: signal, for: mainWindow).start(next: { values in
                        updateState { current in
                            return values.reduce(current, { current, value in
                                return current.withUpdatedValue(value).withRemovedErrors(for: value.value.key)
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

            let removeValueInteractive:([SecureIdValueKey]) -> InputDataValidation = { valueKeys in
                return .fail(.doSomething { f in
                    saveValueDisposable.set(showModalProgress(signal: deleteSecureIdValues(network: account.network, keys: Set(valueKeys)) |> deliverOnMainQueue, for: mainWindow).start(completed: {
                        updateState { current in
                            return valueKeys.reduce(current, { (current, key) in
                                return current.withRemovedValue(key)
                            })
                        }
                        f(.success(.navigationBack))
                    }))
                })
            }

            switch field {
            case .address:
                var loadedData: AddressIntermediateState?
                let push:(SecureIdRequestedFormField, SecureIdRequestedFormField?, Bool) -> Void = { field, relative, hasMainField in
                    presentController(InputDataController(dataSignal: state.get() |> map { state in
                        return addressEntries(state, hasMainField: hasMainField, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in

                        if let _ = data[_id_delete] {
                            return .fail(.doSomething { next in
                                modernConfirm(for: mainWindow, account: account, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, header: L10n.telegramPassportController, information: L10n.secureIdConfirmDeleteDocument, thridTitle: L10n.secureIdConfirmDeleteAddress, successHandler: { result in
                                    var keys: [SecureIdValueKey] = []
                                    if let relative = relative {
                                        keys.append(relative.valueKey)
                                    }
                                    switch result {
                                    case .basic:
                                        break
                                    case .thrid:
                                        keys.append(field.valueKey)
                                    }
                                    next(removeValueInteractive(keys))
                                })
                            })
                        }

                        let current = AddressIntermediateState(data)



                        let street1 = data[_id_street1]?.stringValue ?? ""
                        let street2 = data[_id_street2]?.stringValue ?? ""
                        let city = data[_id_city]?.stringValue ?? ""
                        let state = data[_id_state]?.stringValue ?? ""
                        let countryCode = data[_id_country]?.stringValue ?? ""
                        let postcode = data[_id_postcode]?.stringValue ?? ""

                        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                        if street1.isEmpty && hasMainField {
                            fails[_id_street1] = .shake
                        }
                        if countryCode.isEmpty && hasMainField {
                            fails[_id_country] = .shake
                        }
                        if city.isEmpty && hasMainField {
                            fails[_id_city] = .shake
                        }
                        if postcode.isEmpty && hasMainField {
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

                        if relative != nil, verifiedDocuments.isEmpty {
                            fails[_id_scan] = .shake
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
                            case .passportRegistration:
                                values.append(SecureIdValue.passportRegistration(SecureIdPassportRegistrationValue(verificationDocuments: verifiedDocuments)))
                            case .temporaryRegistration:
                                values.append(SecureIdValue.temporaryRegistration(SecureIdTemporaryRegistrationValue(verificationDocuments: verifiedDocuments)))
                            default:
                                break
                            }
                        }
                        if hasMainField {
                            values.append(SecureIdValue.address(SecureIdAddressValue(street1: street1, street2: street2, city: city, state: state, countryCode: countryCode, postcode: postcode)))
                        }

                        if let loadedData = loadedData {
                            var fails = loadedData.validateErrors(currentState: current, errors: _stateValue.errors(for: .address))
                            if let relative = relative {
                                let errors = _stateValue.errors(for: relative.valueKey)
                                for error in errors {
                                    for i in 0 ..< verifiedDocuments.count {
                                        let file = verifiedDocuments[i]
                                        switch file {
                                        case let .remote(reference):
                                            if error.key == InputDataIdentifier("file_\(reference.fileHash.base64EncodedString())") {
                                                fails[InputDataIdentifier("_file_\(i)")] = .shake
                                            }
                                        default:
                                            break
                                        }
                                    }
                                }
                            }
                            if fails.isEmpty {
                                if loadedData == current && values.last == value {
                                    return .success(.navigationBack)
                                }
                                return proccessValue(values)
                            } else {
                                return .fail(.fields(fails))
                            }
                        }

                        return .fail(.none)
                    }, updateDatas: { data in
                        updateState { current in
                            return current.withUpdatedAddressState(AddressIntermediateState(data))
                        }
                        return .fail(.none)
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedAddressState(nil).withUpdatedValues(current.values)
                        }
                    }, didLoaded: { data in
                        loadedData = AddressIntermediateState(data)
                    }, identifier: "passport"))
                }

                if let editSettings = editSettings {
                    var values:[ValuesSelectorValue<SecureIdRequestedFormField>] = []
                    for relative in relative {
                        values.append(ValuesSelectorValue<SecureIdRequestedFormField>(localized: editSettings.hasValue(relative) ? relative.descEdit : relative.descAdd, value: relative))
                    }
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(selected.value, selected.value == .address ? nil : selected.value, selected.value == .address)
                    }), for: mainWindow)
                } else if relative.count > 1 {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormField>] = relative.map({ValuesSelectorValue(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdResidentialAddress, onComplete: { selected in
                        filePanel(with: photoExts,for: mainWindow, completion: { files in
                            push(field, selected.value, true)
                            if let files = files {
                                let localFiles:[SecureIdVerificationDocument] = files.map({SecureIdVerificationDocument.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                                updateState { current in
                                    return current.withAppendFiles(localFiles, for: selected.value.valueKey)
                                }
                            }
                        })
                    }), for: mainWindow)
                } else if relative.count == 1 {
                    push(field, relative[0], true)
                } else {
                    push(field, nil, true)
                }


            case .personalDetails:
                var loadedData:DetailsIntermediateState?
                let push:(SecureIdRequestedFormField, SecureIdRequestedFormField?, Bool) ->Void = { field, relative, hasMainField in
                    presentController(InputDataController(dataSignal: state.get() |> map { state in
                        return identityEntries(state, hasMainField: hasMainField, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in


                        if let _ = data[_id_delete] {
                            return .fail(.doSomething { next in
                                modernConfirm(for: mainWindow, account: account, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, header: L10n.telegramPassportController, information: hasMainField && relative != nil ? L10n.secureIdConfirmDeleteDocument : hasMainField ? L10n.secureIdDeleteConfirmPersonalDetails : L10n.secureIdConfirmDeleteDocument, thridTitle: hasMainField && relative != nil ? L10n.secureIdDeletePersonalDetails : nil, successHandler: { result in
                                    var keys: [SecureIdValueKey] = []
                                    if let relative = relative {
                                        keys.append(relative.valueKey)
                                    }
                                    switch result {
                                    case .basic:
                                        if hasMainField && relative == nil {
                                            keys.append(field.valueKey)
                                        }
                                    case .thrid:
                                        keys.append(field.valueKey)
                                    }
                                    next(removeValueInteractive(keys))
                                })
                            })
                        }

                        let firstName = data[_id_first_name]?.stringValue ?? ""
                        let lastName = data[_id_last_name]?.stringValue ?? ""
                        let birthday = data[_id_birthday]?.secureIdDate
                        let countryCode = data[_id_country]?.stringValue ?? ""
                        let residence = data[_id_residence]?.stringValue ?? ""
                        let gender = data[_id_gender]?.gender
                        let identifier = data[_id_identifier]?.stringValue

                        let expiryDate = data[_id_expire_date]?.secureIdDate

                        let selfie = data[_id_selfie]?.secureIdDocument
                        let frontside = data[_id_frontside]?.secureIdDocument
                        let backside = data[_id_backside]?.secureIdDocument

                        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                        if firstName.isEmpty && hasMainField {
                            fails[_id_first_name] = .shake
                        }
                        if lastName.isEmpty && hasMainField {
                            fails[_id_last_name] = .shake
                        }
                        if countryCode.isEmpty && hasMainField {
                            fails[_id_country] = .shake
                        }
                        if residence.isEmpty && hasMainField {
                            fails[_id_birthday] = .shake
                        }
                        if gender == nil && hasMainField {
                            fails[_id_gender] = .shake
                        }
                        if birthday == nil && hasMainField {
                            fails[_id_birthday] = .shake
                        }
                        
                        if let identifier = identifier, identifier.isEmpty {
                            fails[_id_identifier] = .shake
                        }


                        if let relative = relative, relative.hasSelfie, selfie == nil {
                            fails[_id_selfie_scan] = .shake
                        }

                        var selfieDocument: SecureIdVerificationDocumentReference? = nil
                        var frontsideDocument: SecureIdVerificationDocumentReference? = nil
                        var backsideDocument: SecureIdVerificationDocumentReference? = nil

                        if let selfie = selfie {
                            switch selfie {
                            case let .remote(reference):
                                selfieDocument = .remote(reference)
                            case let .local(local):
                                switch local.state {
                                case let .uploaded(file):
                                    selfieDocument = .uploaded(file)
                                case .uploading:
                                    fails[_id_selfie] = .shake
                                }
                            }
                        }

                        if let relative = relative {
                            if frontside == nil {
                                fails[_id_frontside] = .shake
                            }
                            if relative.hasBacksideDocument {
                                if backside == nil {
                                    fails[_id_backside] = .shake
                                }
                            }

                            if let frontside = frontside {
                                switch frontside {
                                case let .remote(reference):
                                    frontsideDocument = .remote(reference)
                                case let .local(local):
                                    switch local.state {
                                    case let .uploaded(file):
                                        frontsideDocument = .uploaded(file)
                                    case .uploading:
                                        fails[_id_frontside] = .shake
                                    }
                                }
                            }
                            if let backside = backside {
                                switch backside {
                                case let .remote(reference):
                                    backsideDocument = .remote(reference)
                                case let .local(local):
                                    switch local.state {
                                    case let .uploaded(file):
                                        backsideDocument = .uploaded(file)
                                    case .uploading:
                                        fails[_id_backside] = .shake
                                    }
                                }
                            }
                        }



                        if !fails.isEmpty {
                            return .fail(.fields(fails))
                        }

                      

                        var values: [SecureIdValue] = []
                        if hasMainField {
                            let _birthday = birthday!
                            let _gender = gender!
                            values.append(SecureIdValue.personalDetails(SecureIdPersonalDetailsValue(firstName: firstName, lastName: lastName, birthdate: _birthday, countryCode: countryCode, residenceCountryCode: residence, gender: _gender)))
                        }

                        if let relative = relative {
                            let _identifier = identifier!
                            switch relative.valueKey {
                            case .idCard:
                                values.append(SecureIdValue.idCard(SecureIdIDCardValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument, backSideDocument: backsideDocument)))
                            case .passport:
                                values.append(SecureIdValue.passport(SecureIdPassportValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument)))
                            case .driversLicense:
                                values.append(SecureIdValue.driversLicense(SecureIdDriversLicenseValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument, backSideDocument: backsideDocument)))
                            case .internalPassport:
                                values.append(SecureIdValue.internalPassport(SecureIdInternalPassportValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument)))

                            default:
                                break
                            }
                        }

                        let current = DetailsIntermediateState(data)
                        if let loadedData = loadedData {
                            var fails = loadedData.validateErrors(currentState: current, errors: _stateValue.errors(for: .personalDetails))
                            if let relative = relative {
                                let errors = _stateValue.errors(for: relative.valueKey)
                                for error in errors {
                                    switch error.key {
                                    case _id_selfie:
                                        if let selfieDocument = selfieDocument {
                                            switch selfieDocument {
                                            case .remote:
                                                fails[_id_selfie] = .shake
                                            default:
                                                break
                                            }
                                        }
                                    case _id_frontside:
                                        if let frontsideDocument = frontsideDocument {
                                            switch frontsideDocument {
                                            case .remote:
                                                fails[_id_frontside] = .shake
                                            default:
                                                break
                                            }
                                        }
                                    case _id_frontside:
                                        if let backsideDocument = backsideDocument {
                                            switch backsideDocument {
                                            case .remote:
                                                fails[_id_backside] = .shake
                                            default:
                                                break
                                            }
                                        }
                                    default:
                                        break
                                    }
                                }
                            }
                            if fails.isEmpty {
                                if loadedData == current && values.last == value {
                                    return .success(.navigationBack)
                                }
                                return proccessValue(values)
                            } else {
                                return .fail(.fields(fails))
                            }
                        }

                        return .fail(.none)
                    }, updateDatas: { data in
                        updateState { current in
                            return current.withUpdatedDetailsState(DetailsIntermediateState(data))
                        }
                        return .fail(.none)
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedDetailsState(nil).withUpdatedValues(current.values)
                        }
                    }, didLoaded: { data in
                        loadedData = DetailsIntermediateState(data)
                    }, identifier: "passport"))
                }

                if let editSettings = editSettings {
                    var values:[ValuesSelectorValue<SecureIdRequestedFormField>] = []
                    for relative in relative {
                        values.append(ValuesSelectorValue<SecureIdRequestedFormField>(localized: editSettings.hasValue(relative) ? relative.descEdit : relative.descAdd, value: relative))
                    }
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(selected.value, selected.value == .personalDetails ? nil : selected.value, selected.value == .personalDetails)
                    }), for: mainWindow)
                } else if relative.count > 1 {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormField>] = relative.map({ValuesSelectorValue(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(field, selected.value, true)
//                        filePanel(with: photoExts,for: mainWindow, completion: { files in
//                            if let files = files {
//                                push(field, selected.value)
//                                let localFiles:[SecureIdVerificationDocument] = files.map({SecureIdVerificationDocument.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
//                                updateState { current in
//                                    return current.withAppendFiles(localFiles, for: selected.value.valueKey)
//                                }
//                            }
//                        })
                    }), for: mainWindow)
                } else if relative.count == 1 {
                    push(field, relative[0], true)
                } else {
                    push(field, nil, true)
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
                                    emailNewActivationDisposable.set(showModalProgress(signal: secureIdCommitEmailVerification(postbox: account.postbox, network: account.network, context: context, payload: payload, code: code) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
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
                                        return current.withUpdatedIntermediateEmailState(EmailIntermediateState(email: email, length: payload.length))
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
                    presentController(InputDataController(dataSignal: state.get() |> map { state in
                        return emailEntries(state, updateState: updateState)
                    }, title: title, validateData: validate, updateDatas: { data in
                        if let payload = _payload, let code = data[_id_email_code]?.stringValue, code.length == payload.length {
                            return validate(data)
                        }
                        return .fail(.none)
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedIntermediateEmailState(nil)
                        }
                    }, identifier: "passport"))
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
                                                    presentController(InputDataController(dataSignal: state.get() |> map { state in
                                                        return confirmPhoneNumberEntries(state, phoneNumber: phone, updateState: updateState)
                                                    }, title: title, validateData: { data in
                                                        return .fail(.doSomething { f in
                                                            let code = data[_id_phone_code]?.stringValue ?? ""
                                                            if code.isEmpty {
                                                                f(.fail(.fields([_id_phone_code : .shake])))
                                                                return
                                                            }
                                                            if let context = _stateValue.accessContext {
                                                                phoneNewActivationDisposable.set(showModalProgress(signal: secureIdCommitPhoneVerification(postbox: account.postbox, network: account.network, context: context, payload: payload, code: code) |> deliverOnMainQueue, for: mainWindow).start(next: { value in
                                                                    updateState { current in
                                                                        return current.withUpdatedValue(value)
                                                                    }
                                                                    f(.success(.navigationBack))
                                                                }, error: { error in
                                                                    f(.fail(.fields([_id_phone_code : .shake])))
                                                                }))
                                                            }
                                                        })
                                                    }, identifier: "passport"))
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
                    presentController(InputDataController(dataSignal: state.get() |> map { state in
                        return phoneNumberEntries(state, updateState: updateState)
                    }, title: title, validateData: validate, afterDisappear: {

                    }, identifier: "passport"))
                }
            default:
                fatalError()
            }

        }, createPassword: {
            let promise:Promise<[InputDataEntry]> = Promise()
            promise.set(state.get() |> map { state in
                return createPasswordEntries(state)
            })
            let controller = InputDataController(dataSignal: promise.get(), title: L10n.secureIdCreatePasswordTitle, validateData: { data in

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
            }, identifier: "passport")

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
            if let inAppRequest = inAppRequest {
                authorizeDisposable.set(showModalProgress(signal: state.get() |> take(1) |> mapError { _ in return GrantSecureIdAccessError.generic} |> mapToSignal { state -> Signal<Void, GrantSecureIdAccessError> in
                    return grantSecureIdAccess(network: account.network, peerId: inAppRequest.peerId, publicKey: inAppRequest.publicKey, scope: inAppRequest.scope, opaquePayload: inAppRequest.payload, values: state.values)
                } |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                        alert(for: mainWindow, info: "\(error)")
                }, completed: {
                        executeCallback(true)
                        closeAfterSuccessful()
                }))
            }
            
        }, botPrivacy: { [weak self] in
            if let url = self?.form?.termsUrl {
                execute(inapp: .external(link: url, false))
            }
        }, forgotPassword: {
             recoverPasswordDisposable.set(showModalProgress(signal: requestTwoStepVerificationPasswordRecoveryCode(network: account.network) |> deliverOnMainQueue, for: mainWindow).start(next: { emailPattern in
                presentController(InputDataController(dataSignal: .single(recoverEmailEntries(emailPattern: emailPattern)), title: L10n.secureIdRecoverPassword, validateData: { data -> InputDataValidation in

                    let code = data[_id_email_code]?.stringValue ?? ""
                    if code.isEmpty {
                        return .fail(.fields([_id_email_code : .shake]))
                    }

                    return .fail(.doSomething { f in
                        confirm(for: mainWindow, information: L10n.secureIdWarningDataLost, successHandler: { _ in
                            recoverPasswordDisposable.set(showModalProgress(signal: recoverTwoStepVerificationPassword(network: account.network, code: code) |> deliverOnMainQueue, for: mainWindow).start(error: { error in
                                f(.fail(.fields([_id_email_code : .shake])))
                            }, completed: {
                                updateState { current in
                                    return current.withUpdatedPassword(nil)
                                }
                                passwordVerificationData.set(.single(.notSet(pendingEmailPattern: "")))

                                f(.success(.navigationBack))
                            }))
                        })
                    })

                }, identifier: "passport"))
            }))
       //
        }, deletePassport: {
            confirm(for: mainWindow, header: L10n.secureIdInfoTitle, information: L10n.secureIdInfoDeletePassport, successHandler: { _ in
                updateState { current in
                    let signal = deleteSecureIdValues(network: account.network, keys: Set(current.values.map{$0.value.key}))
                    
                    _ = (signal |> deliverOnMainQueue).start(next: {
                       
                    }, error:{ error in
                        alert(for: mainWindow, info: "\(error)")
                    }, completed: {
                        updateState { current in
                            return current.withRemovedValues()
                        }
                        closeController()
                    })
                    return current
                }
            })
        })
        
        
        let botPeerSignal = form != nil ? account.postbox.loadedPeerWithId(form!.peerId) |> map {Optional($0)} |> deliverOnPrepareQueue : Signal<Peer?, Void>.single(nil)
        
        let signal: Signal<(TableUpdateTransition, Bool, Bool), Void> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, formValue.get() |> deliverOnPrepareQueue, passwordVerificationData.get() |> deliverOnPrepareQueue, state.get() |> deliverOnPrepareQueue, botPeerSignal) |> map { appearance, form, passwordData, state, peer in

            let (entries, enabled) = passportEntries(encryptedForm: form.0, form: form.1, peer: peer, passwordData: passwordData, state: state)

            let converted = entries.map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(converted), right: converted, initialSize: initialSize.modify{$0}, arguments: arguments), enabled, form.1 != nil)
        } |> deliverOnMainQueue |> afterDisposed {
            actionsDisposable.dispose()
        }

        disposable.set(signal.start(next: { [weak self] transition, enabled, isVisible in
            self?.genericView.tableView.merge(with: transition)
            self?.genericView.updateEnabled(enabled, isVisible: isVisible, action: arguments.authorize)
            self?.readyOnce()
        }))
        
    }
    
    override func becomeFirstResponder() -> Bool? {
        return true
    }
    
    private var dismissed:Bool = false
    override func invokeNavigationBack() -> Bool {
        if form == nil {
            return true
        }
        if !dismissed {
            confirm(for: mainWindow, information: L10n.secureIdConfirmCancel, successHandler: { [weak self] _ in
                guard let `self` = self else {return}
                self.dismissed = true
                self.executeCallback(false)
                _ = self.executeReturn()
            })
        }
        
        return dismissed
    }
    
    private func executeCallback(_ success: Bool) {
        if let request = request, let callback = request.callback {
            if callback.hasPrefix("tgbot") {
                let r = callback.nsstring.range(of: "://")
                if r.location != NSNotFound {
                    let rawBotId = callback.nsstring.substring(with: NSMakeRange(5, r.location - 5))
                    if let botId = Int32(rawBotId) {
                        let sdkCallback = "tgbot\(botId)://passport"
                        if sdkCallback == callback {
                            execute(inapp: .external(link: sdkCallback + (success ? "/success" : "/cancel"), false))
                        }
                    }
                }
            } else {
                execute(inapp: .external(link: addUrlParameter(value: "tg_passport=\(success ? "success" : "cancel")", to: callback), false))
            }
        }
    }
    
    deinit {
        disposable.dispose()
    }
    
    override func firstResponder() -> NSResponder? {
        var responder: NSResponder? = nil
        genericView.tableView.enumerateViews { view -> Bool in
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
