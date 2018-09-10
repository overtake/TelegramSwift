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
private let _id_middle_name = InputDataIdentifier("middle_name")
private let _id_last_name = InputDataIdentifier("last_name")
 
 private let _id_first_name_native = InputDataIdentifier("first_name_native")
 private let _id_middle_name_native = InputDataIdentifier("middle_name_native")
 private let _id_last_name_native = InputDataIdentifier("last_name_native")
 
private let _id_birthday = InputDataIdentifier("birth_date")
private let _id_issue_date = InputDataIdentifier("issue_date")
private let _id_expire_date = InputDataIdentifier("expiry_date")
private let _id_identifier = InputDataIdentifier("document_no")

private let _id_country = InputDataIdentifier("country_code")
private let _id_residence = InputDataIdentifier("residence_country_code")
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
private let _id_translation = InputDataIdentifier("translation")

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
    func hasValue(_ relative: SecureIdRequestedFormFieldValue) -> Bool {
        return values.contains(where: {$0.key == relative.valueKey})
    }
}

private func updateFrontMrz(file: String, relative: SecureIdRequestedFormFieldValue, updateState: @escaping ((PassportState)->PassportState)->Void) {
    if let image = NSImage(contentsOfFile: file) {
        let string = recognizeMRZ(image.precomposed(), nil)
        let mrz = TGPassportMRZ.parseLines(string?.components(separatedBy: "\n"))
        let localFile:SecureIdVerificationDocument = .local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: file, randomId: arc4random64()), state: .uploading(0)))
        
        updateState { current in
            var current = current
            if let mrz = mrz {
                if relative.isEqualToMRZ(mrz) {
                    
                    let filedata = try! String(contentsOfFile: Bundle.main.path(forResource: "countries", ofType: nil)!).components(separatedBy: "\n")
                    
                    var citizenship: InputDataValue? = current.detailsIntermediateState?.citizenship
                    var residence: InputDataValue? = current.detailsIntermediateState?.residence
                    
                    for line in filedata {
                        let country = line.components(separatedBy: ";")
                        if let symbols = country.last?.components(separatedBy: ",") {
                            if symbols.contains(mrz.nationality) && citizenship == nil {
                                citizenship = .string(country[1])
                            }
                            if symbols.contains(mrz.issuingCountry) && residence == nil {
                                residence = .string(country[1])
                            }
                        }
                    }
                   
                    
                    let expiryDate = dateFormatter.string(from: mrz.expiryDate).components(separatedBy: ".").map({Int32($0)})
                    let birthDate = dateFormatter.string(from: mrz.birthDate).components(separatedBy: ".").map({Int32($0)})
                    let details = DetailsIntermediateState(firstName: .string(mrz.firstName.lowercased().capitalizingFirstLetter()), middleName: nil, lastName: .string(mrz.lastName.lowercased().capitalizingFirstLetter()), firstNameNative: nil, middleNameNative: nil, lastNameNative: nil, birthday: .date(birthDate[0], birthDate[1], birthDate[2]), citizenship: citizenship, residence: residence, gender: .gender(SecureIdGender.gender(from: mrz)), expiryDate: .date(expiryDate[0], expiryDate[1], expiryDate[2]), identifier: .string(mrz.documentNumber))
                    current = current.withUpdatedDetailsState(details)
                }
            }
            return current.withUpdatedFrontSide(localFile, for: relative.valueKey)
        }
    }
}
 
 private struct FieldRequest : Hashable {
    let primary: SecureIdRequestedFormFieldValue
    let secondary: SecureIdRequestedFormFieldValue?
    let fillPrimary: Bool
    init(_ primary: SecureIdRequestedFormFieldValue, _ secondary: SecureIdRequestedFormFieldValue? = nil, _ fillPrimary: Bool = true) {
        self.primary = primary
        self.secondary = secondary
        self.fillPrimary = fillPrimary
    }
    
    var hashValue: Int {
        return 0
    }
    
    static func ==(lhs: FieldRequest, rhs: FieldRequest) -> Bool {
        return lhs.primary == rhs.primary && lhs.secondary == rhs.secondary
    }
 }

private final class PassportArguments {
    let account: Account
    let checkPassword:((String, ()->Void))->Void
    let requestField:(FieldRequest, SecureIdValue?, SecureIdValue?, [SecureIdRequestedFormFieldValue], EditSettingsValues?)->Void
    let createPassword: ()->Void
    let abortVerification: ()-> Void
    let authorize:(Bool)->Void
    let botPrivacy:()->Void
    let forgotPassword:()->Void
    let deletePassport:()->Void
    init(account: Account, checkPassword:@escaping((String, ()->Void))->Void, requestField:@escaping(FieldRequest, SecureIdValue?, SecureIdValue?, [SecureIdRequestedFormFieldValue], EditSettingsValues?)->Void, createPassword: @escaping()->Void, abortVerification: @escaping()->Void, authorize: @escaping(Bool)->Void, botPrivacy:@escaping()->Void, forgotPassword: @escaping()->Void, deletePassport:@escaping()->Void) {
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
    case emptyFieldId(FieldRequest)
    case filledFieldId(FieldRequest)
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
    case emptyField(sectionId: Int32, index: Int32, fieldType: FieldRequest, value: SecureIdValue?, relativeValue: SecureIdValue?, relative: [SecureIdRequestedFormFieldValue], title: String, desc: String, isError: Bool)
    case filledField(sectionId: Int32, index: Int32, fieldType: FieldRequest, relative: [SecureIdRequestedFormFieldValue], title: String, description: FieldDescription, value: SecureIdValue?, relativeValue: SecureIdValue?)
    case savedField(sectionId: Int32, index: Int32, valueType: SecureIdValueKey, relative: [SecureIdValueKey], relativeValues: [SecureIdValue], title: String, description: String)
    case description(sectionId: Int32, index: Int32, text: String)
    case settingsHeader(sectionId: Int32, index: Int32)
    case requestPassword(sectionId: Int32, index: Int32, hasRecoveryEmail: Bool, isSettings: Bool, error: String?)
    case createPassword(sectionId: Int32, index: Int32, peer: Peer)
    case loading
    case deletePassport(sectionId: Int32, index: Int32)
    case sectionId(Int32)
    
    var stableId: PassportEntryId {
        switch self {
        case .header:
            return .header
        case let .emptyField(_, _, fieldType, _, _, _, _, _, _):
            return .emptyFieldId(fieldType)
        case let .filledField(_, _, fieldType, _, _, _, _, _):
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
        case let .emptyField(section, index, _, _, _, _, _, _, _):
            return (section * 1000) + index
        case let .accept(section, index, _):
            return (section * 1000) + index
        case let .filledField(section, index, _, _, _, _, _, _):
            return (section * 1000) + index
        case let .savedField(section, index, _, _, _, _, _):
            return (section * 1000) + index
        case let .description(section, index, _):
            return (section * 1000) + index
        case let .requestPassword(section, index, _, _, _):
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
        case let .emptyField(_, _, fieldType, value, relativeValue, relative, title, desc, isError):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, description: desc, descTextColor: isError ? theme.colors.redUI : theme.colors.grayText, type: .none, action: {
                arguments.requestField(fieldType, value, relativeValue, relative, nil)
            })
        case let .accept(_, _, enabled):
            return PassportAcceptRowItem(initialSize, stableId: stableId, enabled: enabled, action: {
                arguments.authorize(enabled)
            })
        case let .filledField(_, _, fieldType, relative, title, description, value, relativeValue):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, description: description.text, descTextColor: description.isError ? theme.colors.redUI : theme.colors.grayText, type: .selectable(!description.isError), action: {
                arguments.requestField(fieldType, value, relativeValue, relative, nil)
            })
        case let .savedField(_, _, fieldType, relative, relativeValues, title, description):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: title, description: description, type: .next, action: {
                arguments.requestField(FieldRequest(fieldType.requestFieldType), relativeValues.first(where: {$0.key == fieldType}), nil, relative.map({$0.requestFieldType}), EditSettingsValues(values: relativeValues))
            })
        case .requestPassword(_, _, let hasRecoveryEmail, let isSettings, let error):
            return PassportInsertPasswordItem(initialSize, stableId: stableId, checkPasswordAction: arguments.checkPassword, forgotPassword: arguments.forgotPassword, hasRecoveryEmail: hasRecoveryEmail, isSettings: isSettings, error: error)
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
            }), inset: NSEdgeInsets(left: 30.0, right: 30.0, top: 10, bottom:2))
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
    case let .emptyField(sectionId, index, fieldType, lhsValue, lhsRelativeValue, lhsRelative, title, desc, isError):
        if case .emptyField(sectionId, index, fieldType, let rhsValue, let rhsRelativeValue, let rhsRelative, title, desc, isError) = rhs {
            return lhsRelative == rhsRelative && lhsValue == rhsValue && lhsRelativeValue == rhsRelativeValue
        } else {
            return false
        }
    case let .filledField(sectionId, index, fieldType, lhsRelative, title, description, lhsValue, lhsRelativeValue):
        if case .filledField(sectionId, index, fieldType, let rhsRelative, title, description, let rhsValue, let rhsRelativeValue) = rhs {
            return lhsValue == rhsValue && lhsRelative == rhsRelative && lhsRelativeValue == rhsRelativeValue
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
    case let .requestPassword(sectionId, index, hasRecoveryEmail, isSettings, lhsError):
        if case .requestPassword(sectionId, index, hasRecoveryEmail, isSettings, let rhsError) = rhs {
            return lhsError == rhsError
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
                    
                    if state.tmpPwd == nil {
                        if let peer = peer, let form = encryptedForm {
                            entries.append(.sectionId(sectionId))
                            sectionId += 1
                            
                            entries.append(.sectionId(sectionId))
                            sectionId += 1
                            entries.append(.sectionId(sectionId))
                            sectionId += 1
                            
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
                        
                        entries.append(.sectionId(sectionId))
                        sectionId += 1
                        entries.append(.sectionId(sectionId))
                        sectionId += 1
                        
         
                        
                        entries.append(.requestPassword(sectionId: sectionId, index: index, hasRecoveryEmail: hasRecoveryEmail, isSettings: encryptedForm == nil, error: state.passwordError))
                        index += 1
                    } else {
                        entries.append(.loading)
                    }
                    
                }
            }
            
        } else if let form = form, let peer = peer {
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(.header(sectionId: sectionId, index: index, requestedFields: form.requestedFields, peer: peer))
            index += 1
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(.description(sectionId: sectionId, index: index, text: L10n.secureIdRequestedInformationHeader))
            index += 1
            
            var filledCount: Int32 = 0

            
            let requestedFields = form.requestedFields.map { value -> SecureIdRequestedFormField in
                switch value {
                case let .just(key):
                    switch key {
                    case .email, .phone, .personalDetails, .address:
                        return value
                    default:
                        return .oneOf([key])
                    }
                default:
                    return value
                }
            }
            
            let idCount = requestedFields.filter { $0.isIdentityField }.count
            let adCount = requestedFields.filter { $0.isAddressField }.count
            
            let isDetailsIndepend: Bool = idCount > 1 || idCount == 0
            let isAddressIndepend: Bool = adCount > 1 || adCount == 0
            let hasAddress = requestedFields.filter { value in
                switch value {
                case let .just(value):
                    switch value {
                    case .address:
                        return true
                    default:
                        return false
                    }
                default:
                    return false
                }
            }.count == 1
            
            let hasDetails = requestedFields.filter { value in
                switch value {
                case let .just(value):
                    switch value {
                    case .personalDetails:
                        return true
                    default:
                        return false
                    }
                default:
                    return false
                }
            }.count == 1
            
            var hasNativeName = requestedFields.filter { value in
                switch value {
                case let .just(value):
                    switch value {
                    case let .personalDetails(nativeName):
                        return nativeName
                    default:
                        return false
                    }
                default:
                    return false
                }
            }.count == 1
            
            if hasNativeName, let value = state.searchValue(.personalDetails)?.personalDetails {
                if state.configuration?.nativeLanguageByCountry[value.residenceCountryCode] == "en" {
                    hasNativeName = false
                }
            }
            
            for field in requestedFields {
                switch field {
                case let .just(field):
                    switch field {
                    case .address:
                        if isAddressIndepend {
                            var isFilled: Bool = false
                            let desc: FieldDescription
                            let errors = state.errors[.address] ?? [:]
                            if let value = state.searchValue(field.valueKey), case let .address(address) = value {
                                
                                let errorText = errors[InputDataEmptyIdentifier]?.description ?? (errors.isEmpty ? "" : errors.first!.value.description)
                                if errorText.isEmpty {
                                    let text = [address.street1, address.city, address.state, cManager.item(bySmallCountryName: address.countryCode)?.shortName ?? address.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                                    desc = FieldDescription(text: text)
                                } else {
                                    desc = FieldDescription(text: errorText, isError: true)
                                }
                                isFilled = true

                                entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), relative: [], title: L10n.secureIdRequestPermissionResidentialAddress, description: desc, value: value, relativeValue: nil))
                                filledCount += 1
                                
                            }
                            if !isFilled {
                                entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), value: nil, relativeValue: nil, relative: [], title: L10n.secureIdRequestPermissionResidentialAddress, desc: field.emptyDescription, isError: state.emptyErrors))
                            }
                            index += 1
                        }
                    case .personalDetails:
                        if isDetailsIndepend {
                            var isFilled: Bool = false
                            let desc: FieldDescription
                            let errors = state.errors[.personalDetails] ?? [:]
                            let errorText = errors[InputDataEmptyIdentifier]?.description ?? (errors.isEmpty ? "" : errors.first!.value.description)

                            if let value = state.searchValue(field.valueKey), case let .personalDetails(details) = value, (!hasNativeName || (hasNativeName && details.nativeName != nil)) {
                                if errorText.isEmpty {
                                    let text = [details.latinName.firstName + " " + details.latinName.lastName, details.gender.stringValue, details.birthdate.stringValue, cManager.item(bySmallCountryName: details.countryCode)?.shortName ?? details.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                                    desc = FieldDescription(text: text)
                                } else {
                                    desc = FieldDescription(text: errorText, isError: true)
                                }
                                
                                isFilled = true
                                entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), relative: [], title: L10n.secureIdRequestPermissionPersonalDetails, description: desc, value: value, relativeValue: nil))
                                filledCount += 1
                                
                            }
                            if !isFilled {
                                entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), value: nil, relativeValue: nil, relative: [], title: L10n.secureIdRequestPermissionPersonalDetails, desc: field.emptyDescription, isError: state.emptyErrors))
                            }
                            index += 1
                        }
                    case .email:
                        if let value = state.searchValue(field.valueKey), case let .email(email) = value {
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), relative: [], title: field.rawValue, description: FieldDescription(text: email.email), value: value, relativeValue: nil))
                            filledCount += 1

                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), value: nil, relativeValue: nil, relative: [], title: field.rawValue, desc: field.emptyDescription, isError: state.emptyErrors))
                        }
                        index += 1
                    case .phone:
                        if let value = state.searchValue(field.valueKey), case let .phone(phone) = value {
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), relative: [], title: field.rawValue, description: FieldDescription(text: formatPhoneNumber(phone.phone)), value: value, relativeValue: nil))
                            filledCount += 1
                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(field), value: nil, relativeValue: nil, relative: [], title: field.rawValue, desc: field.emptyDescription, isError: state.emptyErrors))
                        }
                        index += 1
                    default:
                        fatalError()
//                        entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(field.primary, field, hasDetails && !isDetailsIndepend), relative: [field], title: field.rawValue, desc: field.emptyDescription, isError: state.emptyErrors))
//                        index += 1
                    }
                case let .oneOf(fields):
                   
                    var descText: String
                    if fields.count == 1 {
                        descText = L10n.secureIdUploadScanSingle(fields[0].rawValue.lowercased())
                    } else {
                        let all = fields.prefix(fields.count - 1).reduce("", { current, value in
                            if current.isEmpty {
                                return value.rawValue.lowercased()
                            }
                            return current + ", " + value.rawValue.lowercased()
                        })
                        descText = L10n.secureIdUploadScanMulti(all, fields[fields.count - 1].rawValue.lowercased())
                    }
                    
                    switch fields[0] {
                    case .bankStatement, .rentalAgreement, .utilityBill, .passportRegistration, .temporaryRegistration:
                        
                        let secondary:SecureIdValue? = fields.compactMap {state.searchValue($0.valueKey)}.first
                        let address = hasAddress ? state.searchValue(.address) : nil
                        
                        let title: String
                        switch fields.count {
                        case 1:
                            title = fields[0].rawValue
                        case 2:
                            title = L10n.secureIdRequestTwoDocumentsTitle(fields[0].rawValue, fields[1].rawValue)
                        default:
                            title = L10n.secureIdRequestPermissionResidentialAddress
                        }
                        
                        if let secondary = secondary?.verificationDocuments {
                             descText = L10n.secureIdAddressScansCountable(secondary.count)
                        }
                        
                        if let value = address, case let .address(address) = value, !isAddressIndepend {
                            descText = (secondary?.verificationDocuments != nil ? descText + ", " : "") + [address.street1, address.city, address.state, cManager.item(bySmallCountryName: address.countryCode)?.shortName ?? address.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                        }
                        
                        
                        if let secondary = secondary?.verificationDocuments, address == nil {
                            descText = L10n.secureIdAddressScansCountable(secondary.count)
                        } else if let value = address, case let .address(address) = value, hasAddress && !isAddressIndepend {
                            descText = [address.street1, address.city, address.state, cManager.item(bySmallCountryName: address.countryCode)?.shortName ?? address.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                        }
                        
                        if fields.count > 1, let secondary = secondary  {
                            descText = secondary.requestFieldType.rawValue + ", " + descText
                        }
                        
                        var isUnfilled: Bool = false
                        
                        if let secondary = secondary {
                            if let result = fields.filter({secondary.requestFieldType.valueKey == $0.valueKey}).first {
                                if result.hasTranslation && (secondary.translations == nil || secondary.translations!.isEmpty) {
                                    isUnfilled = true
                                    descText = L10n.secureIdRequestUploadTranslation
                                }
                            }
                        }
                        
                      
                      
                        var relative: [SecureIdRequestedFormFieldValue] = fields
                        if let secondary = secondary {
                            relative = [fields.filter({secondary.requestFieldType.valueKey == $0.valueKey}).first!]
                        }
                        
                        var errors:[InputDataIdentifier : InputDataValueError] = [:]
                        
                        
                        if hasAddress && !isAddressIndepend {
                            let primary = (state.errors[.address] ?? [:])
                            for (key, value) in primary {
                                errors[key] = value
                            }
                        }
                        for field in fields {
                            let secondary = (state.errors[field.valueKey] ?? [:])
                            for (key, value) in secondary {
                                errors[key] = value
                            }
                        }
                        
                        let errorText = errors[InputDataEmptyIdentifier]?.description ?? (errors.isEmpty ? "" : errors.first!.value.description)
                        
                        if !errorText.isEmpty {
                            descText = errorText
                        }
                        let addressField:SecureIdRequestedFormFieldValue = requestedFields.filter({$0.valueKey == .address}).first?.fieldValue ?? .address

                        if let secondary = secondary, (!hasAddress || isAddressIndepend || (hasAddress && address != nil)), !isUnfilled {
                            let desc: FieldDescription = FieldDescription(text: descText, isError: !errorText.isEmpty)
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(addressField, relative[0], hasAddress && !isAddressIndepend), relative: relative, title: title, description: desc, value: address, relativeValue: secondary))
                            if !desc.isError {
                                filledCount += 1
                            }
                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(addressField, relative[0], hasAddress && !isAddressIndepend), value: address, relativeValue: secondary, relative: relative, title: title, desc: descText, isError: state.emptyErrors))
                        }
                        
                        index += 1
                    case .passport, .idCard, .driversLicense, .internalPassport:
                        
                        let secondary:SecureIdValue? = fields.compactMap {state.searchValue($0.valueKey)}.first
                        let details = hasDetails ? state.searchValue(.personalDetails) : nil
                        
                        let title: String
                        switch fields.count {
                        case 1:
                            title = fields[0].rawValue
                        case 2:
                            title = L10n.secureIdRequestTwoDocumentsTitle(fields[0].rawValue, fields[1].rawValue)
                        default:
                            title = L10n.secureIdRequestPermissionIdentityDocument
                        }
                        
                        
                        if let secondary = secondary {
                            descText = secondary.identifier ?? ""
                        }
                        
                        
                        if let value = details, case let .personalDetails(details) = value, hasDetails && !isDetailsIndepend {
                            descText = (secondary != nil ? descText + ", " : "") + [details.latinName.firstName + " " + details.latinName.lastName, details.gender.stringValue, details.birthdate.stringValue, cManager.item(bySmallCountryName: details.countryCode)?.shortName ?? details.countryCode].compactMap {$0}.filter {!$0.isEmpty}.joined(separator: ", ")
                        }
                        
                        if fields.count > 1, let secondary = secondary  {
                            descText = secondary.requestFieldType.rawValue + ", " + descText
                        }
                        
                        var isUnfilled: Bool = false
                        
                        if let secondary = secondary {
                            if let result = fields.filter({secondary.requestFieldType.valueKey == $0.valueKey}).first {
                                if result.hasSelfie && secondary.selfieVerificationDocument == nil {
                                    isUnfilled = true
                                    descText = L10n.secureIdRequestUploadSelfie
                                }
                                if result.hasTranslation && (secondary.translations == nil || secondary.translations!.isEmpty) {
                                    isUnfilled = true
                                    descText = L10n.secureIdRequestUploadTranslation
                                }
                            }
                        }
 
                        var relative: [SecureIdRequestedFormFieldValue] = fields
                        
                        
                        if let secondary = secondary {
                            relative = [fields.filter({secondary.requestFieldType.valueKey == $0.valueKey}).first!]
                        }
                        
                        var errors:[InputDataIdentifier : InputDataValueError] = [:]

                        
                        if hasDetails && !isDetailsIndepend {
                            let primary = (state.errors[.personalDetails] ?? [:])
                            for (key, value) in primary {
                                errors[key] = value
                            }
                        }
                        for field in fields {
                            let secondary = (state.errors[field.valueKey] ?? [:])
                            for (key, value) in secondary {
                                errors[key] = value
                            }
                        }
                        
                        let errorText = errors[InputDataEmptyIdentifier]?.description ?? (errors.isEmpty ? "" : errors.first!.value.description)

                        if !errorText.isEmpty {
                            descText = errorText
                        }
                        
                        let personalField:SecureIdRequestedFormFieldValue = requestedFields.filter({$0.valueKey == .personalDetails}).first?.fieldValue ?? .personalDetails(nativeName: true)
                        
                        if let secondary = secondary, (!hasDetails || isDetailsIndepend || (hasDetails && details != nil)), !isUnfilled, (!hasNativeName || (hasNativeName && details?.personalDetails?.nativeName != nil)) {
                            let desc: FieldDescription = FieldDescription(text: descText, isError: !errorText.isEmpty)
                            entries.append(.filledField(sectionId: sectionId, index: index, fieldType: FieldRequest(personalField, relative[0], hasDetails && !isDetailsIndepend), relative: relative, title: title, description: desc, value: details, relativeValue: secondary))
                            if !desc.isError {
                                filledCount += 1
                            }

                        } else {
                            entries.append(.emptyField(sectionId: sectionId, index: index, fieldType: FieldRequest(personalField, relative[0], hasDetails && !isDetailsIndepend), value: details, relativeValue: secondary, relative: relative, title: title, desc: descText, isError: state.emptyErrors))
                        }
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
            
            enabled = filledCount == (requestedFields.count - (hasDetails && !isDetailsIndepend ? 1 : 0) - (hasAddress && !isAddressIndepend ? 1 : 0))
            
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
    let middleName: InputDataValue?
    let lastName: InputDataValue?
    let firstNameNative: InputDataValue?
    let middleNameNative: InputDataValue?
    let lastNameNative: InputDataValue?
    
    let birthday: InputDataValue?
    let citizenship: InputDataValue?
    let residence: InputDataValue?
    let gender: InputDataValue?
    let expiryDate: InputDataValue?
    let identifier: InputDataValue?
    init(firstName: InputDataValue?, middleName: InputDataValue?, lastName: InputDataValue?, firstNameNative: InputDataValue?, middleNameNative: InputDataValue?, lastNameNative: InputDataValue?, birthday: InputDataValue?, citizenship: InputDataValue?, residence: InputDataValue?, gender: InputDataValue?, expiryDate: InputDataValue?, identifier: InputDataValue?) {
        self.firstName = firstName
        self.middleName = middleName
        self.lastName = lastName
        self.firstNameNative = firstNameNative
        self.lastNameNative = lastNameNative
        self.middleNameNative = middleNameNative
        self.birthday = birthday
        self.citizenship = citizenship
        self.residence = residence
        self.gender = gender
        self.expiryDate = expiryDate
        self.identifier = identifier
    }
    
    convenience init(_ data: [InputDataIdentifier : InputDataValue]) {
        self.init(firstName: data[_id_first_name], middleName: data[_id_middle_name], lastName: data[_id_last_name], firstNameNative: data[_id_first_name_native], middleNameNative: data[_id_middle_name_native], lastNameNative: data[_id_last_name_native], birthday: data[_id_birthday], citizenship: data[_id_country], residence: data[_id_residence], gender: data[_id_gender], expiryDate: data[_id_expire_date], identifier: data[_id_identifier])
    }
    
    fileprivate func validateErrors(currentState: DetailsIntermediateState, errors:[InputDataIdentifier : InputDataValueError]?, relativeErrors: [InputDataIdentifier : InputDataValueError]?) -> [InputDataIdentifier : InputDataValidationFailAction] {
        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
        
        if errors?[_id_first_name] != nil, currentState.firstName == firstName {
            fails[_id_first_name] = .shake
        }
        if errors?[_id_middle_name] != nil, currentState.middleName == middleName {
            fails[_id_middle_name] = .shake
        }
        if errors?[_id_last_name] != nil, currentState.lastName == lastName {
            fails[_id_last_name] = .shake
        }
        
        if errors?[_id_first_name_native] != nil, currentState.firstNameNative == firstNameNative {
            fails[_id_first_name_native] = .shake
        }
        if errors?[_id_middle_name_native] != nil, currentState.middleNameNative == middleNameNative {
            fails[_id_middle_name_native] = .shake
        }
        if errors?[_id_last_name_native] != nil, currentState.lastNameNative == lastNameNative {
            fails[_id_last_name_native] = .shake
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
        
        if relativeErrors?[_id_expire_date] != nil, currentState.expiryDate == expiryDate {
            fails[_id_expire_date] = .shake
        }
        if relativeErrors?[_id_identifier] != nil, currentState.identifier == identifier {
            fails[_id_identifier] = .shake
        }
        return fails
    }
    
    fileprivate func removeErrors(currentState: DetailsIntermediateState, errors:[InputDataIdentifier : InputDataValueError]?, relativeErrors: [InputDataIdentifier : InputDataValueError]?) -> (errors: [InputDataIdentifier : InputDataValueError], relativeErrors: [InputDataIdentifier : InputDataValueError]) {
        
        var errors = errors ?? [:]
        var relativeErrors = relativeErrors ?? [:]
        
        if errors[_id_first_name] != nil, currentState.firstName != firstName {
            errors.removeValue(forKey: _id_first_name)
        }
        if errors[_id_middle_name] != nil, currentState.middleName != middleName {
            errors.removeValue(forKey: _id_middle_name)
        }
        if errors[_id_last_name] != nil, currentState.lastName != lastName {
            errors.removeValue(forKey: _id_last_name)
        }
        
        if errors[_id_first_name_native] != nil, currentState.firstNameNative != firstNameNative {
            errors.removeValue(forKey: _id_first_name_native)
        }
        if errors[_id_middle_name_native] != nil, currentState.middleNameNative != middleNameNative {
            errors.removeValue(forKey: _id_middle_name_native)
        }
        if errors[_id_last_name_native] != nil, currentState.lastNameNative != lastNameNative {
            errors.removeValue(forKey: _id_last_name_native)
        }
        
        if errors[_id_birthday] != nil, currentState.birthday != birthday {
            errors.removeValue(forKey: _id_birthday)
        }
        if errors[_id_country] != nil, currentState.citizenship != citizenship {
            errors.removeValue(forKey: _id_country)
        }
        if errors[_id_residence] != nil, currentState.residence != residence {
            errors.removeValue(forKey: _id_residence)
        }
        if errors[_id_gender] != nil, currentState.gender != gender {
            errors.removeValue(forKey: _id_gender)
        }
        
        if relativeErrors[_id_expire_date] != nil, currentState.expiryDate != expiryDate {
            relativeErrors.removeValue(forKey: _id_expire_date)
        }
        if relativeErrors[_id_identifier] != nil, currentState.identifier != identifier {
            relativeErrors.removeValue(forKey: _id_identifier)
        }
        return (errors: errors, relativeErrors: relativeErrors)
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
    
    fileprivate func removeErrors(currentState: AddressIntermediateState, errors:[InputDataIdentifier : InputDataValueError]?) -> [InputDataIdentifier : InputDataValueError] {
        
        var errors = errors ?? [:]
        
        if errors[_id_street1] != nil, currentState.street1 != street1 {
            errors.removeValue(forKey: _id_street1)
        }
        if errors[_id_street2] != nil, currentState.street2 != street2 {
            errors.removeValue(forKey: _id_street2)
        }
        if errors[_id_state] != nil, currentState.state != state {
            errors.removeValue(forKey: _id_state)
        }
        if errors[_id_city] != nil, currentState.city != city {
            errors.removeValue(forKey: _id_city)
        }
        if errors[_id_country] != nil, currentState.countryCode != countryCode {
            errors.removeValue(forKey: _id_country)
        }
        if errors[_id_postcode] != nil, currentState.postcode != postcode {
            errors.removeValue(forKey: _id_postcode)
        }
        
        return errors
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
    let translations: [SecureIdValueKey : [SecureIdVerificationDocument]]
    let frontSideFile: [SecureIdValueKey : SecureIdVerificationDocument]
    let backSideFile: [SecureIdValueKey : SecureIdVerificationDocument]
    
    let viewState: PassportViewState
    
    let emptyErrors:Bool
    
    let tmpPwd: String?
    
    let configuration: SecureIdConfiguration?
    
    let passwordError: String?
    
    init(account: Account, peer: Peer, tmpPwd: String?, viewState: PassportViewState, errors: [SecureIdValueKey: [InputDataIdentifier : InputDataValueError]] = [:], passwordSettings:TwoStepVerificationSettings? = nil, password: UpdateTwoStepVerificationPasswordResult? = nil, values: [SecureIdValueWithContext] = [], accessContext: SecureIdAccessContext? = nil, verifyDocumentContext: SecureIdVerificationDocumentsContext? = nil, files: [SecureIdValueKey : [SecureIdVerificationDocument]] = [:], emailIntermediateState: EmailIntermediateState? = nil, detailsIntermediateState: DetailsIntermediateState? = nil, addressIntermediateState: AddressIntermediateState? = nil, selfies: [SecureIdValueKey : SecureIdVerificationDocument] = [:], translations: [SecureIdValueKey : [SecureIdVerificationDocument]] = [:], frontSideFile: [SecureIdValueKey : SecureIdVerificationDocument] = [:], backSideFile: [SecureIdValueKey : SecureIdVerificationDocument] = [:], emptyErrors: Bool = false, configuration: SecureIdConfiguration? = nil, passwordError: String? = nil) {
        self.account = account
        self.peer = peer
        self.errors = errors
        self.passwordSettings = passwordSettings
        self.password = password
        self.values = values
        self.viewState = viewState
        self.tmpPwd = tmpPwd
        self.accessContext = accessContext
        self.verifyDocumentContext = verifyDocumentContext
        self.files = files
        self.emailIntermediateState = emailIntermediateState
        self.detailsIntermediateState = detailsIntermediateState
        self.addressIntermediateState = addressIntermediateState
        self.selfies = selfies
        self.translations = translations
        self.frontSideFile = frontSideFile
        self.backSideFile = backSideFile
        self.emptyErrors = emptyErrors
        self.configuration = configuration
        self.passwordError = passwordError
        let translations:[SecureIdVerificationDocument] = translations.reduce([], { current, value in
            return current + value.value
        })
        
        self.verifyDocumentContext?.stateUpdated(files.reduce(Array(selfies.values) + Array(frontSideFile.values) + Array(backSideFile.values) + translations, { (current, value) -> [SecureIdVerificationDocument] in
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
    
    
    func withUpdatedTmpPwd(_ tmpPwd: String?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedPassword(_ password: UpdateTwoStepVerificationPasswordResult?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedPasswordSettings(_ settings: TwoStepVerificationSettings?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: settings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
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
        
        var translations = self.translations
        if let translationsDocuments = value.value.translations {
            translations[value.value.key] = translationsDocuments.compactMap { reference in
                switch reference {
                case let .remote(file):
                    return .remote(file)
                default:
                    return nil
                }
            }
        }
        
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, translations: translations, frontSideFile: frontSideFile, backSideFile: backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
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
        
        var translations = self.translations
        translations.removeValue(forKey: key)
        
        var selfies = self.selfies
        selfies.removeValue(forKey: key)
        
        var frontSideFile = self.frontSideFile
        frontSideFile.removeValue(forKey: key)
        
        var backSideFile = self.backSideFile
        backSideFile.removeValue(forKey: key)
        
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, translations: translations, frontSideFile: frontSideFile, backSideFile: backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedAccessContext(_ accessContext: SecureIdAccessContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedVerifyDocumentContext(_ verifyDocumentContext: SecureIdVerificationDocumentsContext) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
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
        
        var translations = self.translations
        
        loop: for (key, _values) in self.translations {
            var values = _values
            for i in 0 ..< _values.count {
                let value = values[i]
                if value.id.hashValue == id {
                    switch value {
                    case var .local(document):
                        document.state = state
                        values[i] = .local(document)
                        translations[key] = values
                        break loop
                    default:
                        break
                    }
                }
            }
        }
        
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: selfies, translations: translations, frontSideFile: frontSideFile, backSideFile: backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withAppendTranslations(_ translations: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var current = self.translations[valueKey] ?? []
        current.append(contentsOf: translations)
        current = Array(current.prefix(scansLimit))
        var dictionary = self.translations
        dictionary[valueKey] = current
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: dictionary, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedTranslations(_ translations: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var dictionary = self.translations
        dictionary[valueKey] = translations
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: dictionary, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withRemovedTranslation(_ translation: SecureIdVerificationDocument, for valueKey: SecureIdValueKey) -> PassportState {
        var translations = self.translations[valueKey] ?? []
        for i in 0 ..< translations.count {
            if translations[i].id == translation.id {
                translations.remove(at: i)
                break
            }
        }
        var dictionary = self.translations
        dictionary[valueKey] = translations
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: dictionary, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    
    func withAppendFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var current = self.files[valueKey] ?? []
         current.append(contentsOf: files)
        current = Array(current.prefix(scansLimit))
        var dictionary = self.files
        dictionary[valueKey] = current
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedFiles(_ files: [SecureIdVerificationDocument], for valueKey: SecureIdValueKey) -> PassportState {
        var dictionary = self.files
        dictionary[valueKey] = files
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
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
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: dictionary, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withRemovedValues() -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: [], accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: [:], emailIntermediateState: emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: [:], translations: [:], frontSideFile: [:], backSideFile: [:], emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedIntermediateEmailState(_ emailIntermediateState: EmailIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedDetailsState(_ detailsIntermediateState: DetailsIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: detailsIntermediateState, addressIntermediateState: addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    func withUpdatedAddressState(_ addressState: AddressIntermediateState?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: addressState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    func withUpdatedViewState(_ viewState: PassportViewState) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    func withUpdatedSelfie(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var selfies = self.selfies
        if let value = value {
            selfies[key] = value
        } else {
            selfies.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedFrontSide(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var frontSideFile = self.frontSideFile
        if let value = value {
            frontSideFile[key] = value
        } else {
            frontSideFile.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedBackSide(_ value: SecureIdVerificationDocument?, for key: SecureIdValueKey) -> PassportState {
        var backSideFile = self.backSideFile
        if let value = value {
            backSideFile[key] = value
        } else {
            backSideFile.removeValue(forKey: key)
        }
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedEmptyErrors(_ emptyErrors: Bool) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedPasswordError(_ passwordError: String?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: passwordError)
    }
    
    func withRemovedInputErrors() -> PassportState {
        var errors = self.errors
        for (key, value) in self.errors {
            errors[key] = value.filter({$0.value != latinError})
        }
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withRemovedError(for valueKey:SecureIdValueKey, field: InputDataIdentifier) -> PassportState {
        var valyeErrors = self.errors[valueKey] ?? [:]
        valyeErrors = valyeErrors.filter({$0.key != field})
        var errors = self.errors
        errors[valueKey] = valyeErrors
        
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
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
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    func withUpdatedErrors(_ errors: [SecureIdValueKey: [InputDataIdentifier : InputDataValueError]]) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: self.configuration, passwordError: self.passwordError)
    }
    
    func withUpdatedConfiguration(_ configuration: SecureIdConfiguration?) -> PassportState {
        return PassportState(account: self.account, peer: self.peer, tmpPwd: self.tmpPwd, viewState: self.viewState, errors: self.errors, passwordSettings: self.passwordSettings, password: self.password, values: self.values, accessContext: self.accessContext, verifyDocumentContext: self.verifyDocumentContext, files: self.files, emailIntermediateState: self.emailIntermediateState, detailsIntermediateState: self.detailsIntermediateState, addressIntermediateState: self.addressIntermediateState, selfies: self.selfies, translations: self.translations, frontSideFile: self.frontSideFile, backSideFile: self.backSideFile, emptyErrors: self.emptyErrors, configuration: configuration, passwordError: self.passwordError)
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
    
    if lhs.translations.count != rhs.translations.count {
        return false
    } else {
        for (lhsKey, lhsValue) in lhs.translations {
            let rhsValue = rhs.translations[lhsKey]
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
    
    
    return lhs.passwordSettings?.email == rhs.passwordSettings?.email && lhs.password == rhs.password && lhs.values == rhs.values && (lhs.accessContext == nil && rhs.accessContext == nil) && lhs.emailIntermediateState == rhs.emailIntermediateState && lhs.detailsIntermediateState == rhs.detailsIntermediateState && lhs.addressIntermediateState == rhs.addressIntermediateState && lhs.errors == rhs.errors && lhs.viewState == rhs.viewState && lhs.tmpPwd == rhs.tmpPwd && lhs.emptyErrors == rhs.emptyErrors && lhs.passwordError == rhs.passwordError
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
    
    var placeholder = state.searchValue(.email)?.emailValue?.email ?? ""

    
    if let email = state.emailIntermediateState?.email, !email.isEmpty {
        
        if placeholder == email {
            placeholder = ""
        }
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_email_code, mode: .plain, placeholder: L10n.secureIdEmailActivateCodePlaceholder, inputPlaceholder: L10n.secureIdEmailActivateCodeInputPlaceholder, filter: {String($0.unicodeScalars.filter { CharacterSet.decimalDigits.contains($0)})}, limit: Int32(email.length)))
        index += 1
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdEmailActivateDescription(email), color: theme.colors.grayText, detectBold: true))
        index += 1
        
        return entries
        
    } else  if let email = state.passwordSettings?.email, !email.isEmpty {
        
        if placeholder == email {
            placeholder = ""
        }
        
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(email), error: nil, identifier: _id_email_def, name: L10n.secureIdEmailUseSame(email), color: theme.colors.blueUI, icon: nil, type: .next))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }
    
    
    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: .string(placeholder), error: nil, identifier: _id_email_new, mode: .plain, placeholder: L10n.secureIdEmailEmailPlaceholder, inputPlaceholder: L10n.secureIdEmailEmailInputPlaceholder, filter: {$0}, limit: 254))
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

private func addressEntries( _ state: PassportState, hasMainField: Bool, relative: SecureIdRequestedFormFieldValue?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    let nonFilter:(String)->String = { value in
        return value
    }
    
    
    let address: SecureIdAddressValue? = hasMainField ? state.searchValue(.address)?.addressValue : nil
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
            let entry = country.components(separatedBy: ";")
            if entry.count >= 3 {
                return ValuesSelectorValue(localized: entry[2], value: .string(entry[1]))
            } else {
                return nil
            }
        }.sorted(by: { $0.localized < $1.localized})
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.addressIntermediateState?.countryCode ?? .string(address?.countryCode), error: aErrors?[_id_country], identifier: _id_country, placeholder: L10n.secureIdAddressCountryPlaceholder, values: countries))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.addressIntermediateState?.postcode ?? .string(address?.postcode), error: aErrors?[_id_postcode], identifier: _id_postcode, mode: .plain, placeholder: L10n.secureIdAddressPostcodePlaceholder, inputPlaceholder: L10n.secureIdAddressPostcodeInputPlaceholder, filter: { text in
            return latinFilter(text, .address, _id_postcode, false, updateState)
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
                            if localFiles.count + (current.files[relative.valueKey] ?? []).count > scansLimit {
                                alert(for: mainWindow, info: L10n.secureIdErrorScansLimit)
                            }
                            return current.withAppendFiles(localFiles, for: relative.valueKey).withRemovedError(for: relative.valueKey, field: _id_scan)
                        }
                    }
                })
            }))
            index += 1
        }
       
        
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityScanDescription, color: theme.colors.grayText, detectBold: true))
        index += 1
        
        
        if relative.hasTranslation {
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdTranslationHeader, color: theme.colors.grayText, detectBold: true))
            index += 1
            
            if let translationError = rErrors?[_id_translation] {
                entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: translationError.description, color: theme.colors.redUI, detectBold: true))
                index += 1
            }
            
            let translations = state.translations[relative.valueKey] ?? []
            
            var fileIndex = 0
            
            if let accessContext = state.accessContext {
                for translation in translations {
                    let header = L10n.secureIdScanNumber(Int(fileIndex + 1))
                    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(translation), identifier:  InputDataIdentifier("_translation_\(fileIndex)"), equatable: InputDataEquatable(translation), item: { initialSize, stableId -> TableRowItem in
                        return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: translation, context: accessContext, stableId: stableId), error: rErrors?[translation.errorIdentifier], header: header, removeAction: { value in
                            updateState { current in
                                return current.withRemovedTranslation(value, for: relative.valueKey)
                            }
                        })
                    }))
                    fileIndex += 1
                    index += 1
                }
            }
            
            if translations.count < scansLimit {
                entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_translation, placeholder: translations.count > 0 ? L10n.secureIdUploadAdditionalScan : L10n.secureIdUploadScan, description: nil, icon: nil, action: {
                    filePanel(with: photoExts, allowMultiple: true, for: mainWindow, completion: { files in
                        if let files = files {
                            let localFiles:[SecureIdVerificationDocument] = files.map({.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                            
                            updateState { current in
                                if localFiles.count + (current.translations[relative.valueKey] ?? []).count > scansLimit {
                                    alert(for: mainWindow, info: L10n.secureIdErrorScansLimit)
                                }
                                return current.withAppendTranslations(localFiles, for: relative.valueKey).withRemovedError(for: relative.valueKey, field: _id_translation)
                            }
                        }
                    })
                }))
                index += 1
            }
            
            
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdTranslationDesc, color: theme.colors.grayText, detectBold: true))
            index += 1
        }
        
    }
    
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    if address != nil || relativeValue != nil {
        entries.append(InputDataEntry.general(sectionId: sectionId, index: index, value: .string(nil), error: nil, identifier: _id_delete, name: relativeValue != nil ? L10n.secureIdDeleteIdentity : L10n.secureIdDeleteAddress, color: theme.colors.redUI, icon: nil, type: .none))
        entries.append(.sectionId(sectionId))
        sectionId += 1
    }

    return entries
    
}
 fileprivate  let latinError = InputDataValueError(description: L10n.secureIdInputErrorLatinOnly, target: .data)
 
 private func latinFilter(_ text: String, _ valueKey: SecureIdValueKey, _ identifier: InputDataIdentifier, _ includeNumbers: Bool, _ updateState: @escaping((PassportState)->PassportState)->Void) -> String {

    let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    let lower = "abcdefghijklmnopqrstuvwxyz"
    let updated = text.trimmingCharacters(in: CharacterSet(charactersIn: upper + lower + (includeNumbers ? "0987654321-" : "")).inverted)
    if updated != text {
        updateState { current in
            var errors = current.errors
            var rErrors = errors[valueKey] ?? [:]
            rErrors[identifier] = latinError
            errors[valueKey] = rErrors
            return current.withUpdatedErrors(errors)
        }
    } else {
        updateState { current in
            var errors = current.errors
            var rErrors = errors[valueKey] ?? [:]
            if rErrors[identifier] == latinError {
                rErrors.removeValue(forKey: identifier)
            }
            errors[valueKey] = rErrors
            return current.withUpdatedErrors(errors)
        }
    }
    return updated
 }

private func identityEntries( _ state: PassportState, primary: SecureIdRequestedFormFieldValue?, relative: SecureIdRequestedFormFieldValue?, updateState: @escaping ((PassportState)->PassportState)->Void)->[InputDataEntry] {
    var entries:[InputDataEntry] = []
    var sectionId:Int32 = 0
    var index: Int32 = 0
    entries.append(.sectionId(sectionId))
    sectionId += 1
    
    
    let personalDetails: SecureIdPersonalDetailsValue? = primary != nil ? state.searchValue(primary!.valueKey)?.personalDetails : nil
    let relativeValue: SecureIdValue? = relative == nil ? nil : state.searchValue(relative!.valueKey)
   
    let pdErrors = state.errors[.personalDetails]

    
    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityDocumentDetailsHeader, color: theme.colors.grayText, detectBold: true))
    index += 1
    
    
    
    
    let addRelativeIdentifier:()->Void = {
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
            
            
            entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.identifier ?? .string(relativeValue?.identifier), error: rErrors?[_id_identifier], identifier: _id_identifier, mode: .plain, placeholder: title, inputPlaceholder: subtitle, filter: { text in
                return latinFilter(text, relative.valueKey, _id_identifier, true, updateState)
            }, limit: 20))
            index += 1
            
            entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.expiryDate ?? relativeValue?.expiryDate?.inputDataValue ?? .date(nil, nil, nil), error: rErrors?[_id_expire_date], identifier: _id_expire_date, placeholder: L10n.secureIdIdentityPlaceholderExpiryDate))
            index += 1
        }
    }
    
    if let primary = primary {
        entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdIdentityNameInLatine, color: theme.colors.grayText, detectBold: true))
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.firstName ?? .string(personalDetails?.latinName.firstName ?? ""), error: pdErrors?[_id_first_name], identifier: _id_first_name, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderFirstName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderFirstName, filter: { text in
            return latinFilter(text, primary.valueKey, _id_first_name, false, updateState)
        }, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.middleName ?? .string(personalDetails?.latinName.middleName ?? ""), error: pdErrors?[_id_middle_name], identifier: _id_middle_name, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderMiddleName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderMiddleName, filter: { text in
            return latinFilter(text, primary.valueKey, _id_middle_name, false, updateState)
        }, limit: 255))
        index += 1
        
        entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.lastName ?? .string(personalDetails?.latinName.lastName ?? ""), error: pdErrors?[_id_last_name], identifier: _id_last_name, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderLastName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderLastName, filter: { text in
            return latinFilter(text, primary.valueKey, _id_last_name, false, updateState)
        }, limit: 255))
        index += 1
        
        let genders:[ValuesSelectorValue<InputDataValue>] = [ValuesSelectorValue(localized: L10n.secureIdGenderMale, value: .gender(.male)), ValuesSelectorValue(localized: L10n.secureIdGenderFemale, value: .gender(.female))]
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.gender ?? .gender(personalDetails?.gender), error: pdErrors?[_id_gender], identifier: _id_gender, placeholder: L10n.secureIdIdentityPlaceholderGender, values: genders))
        index += 1
        
        entries.append(InputDataEntry.dateSelector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.birthday ?? personalDetails?.birthdate.inputDataValue ?? .date(nil, nil, nil), error: pdErrors?[_id_birthday], identifier: _id_birthday, placeholder: L10n.secureIdIdentityPlaceholderBirthday))
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
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.citizenship ?? .string(personalDetails?.countryCode), error: pdErrors?[_id_country], identifier: _id_country, placeholder: L10n.secureIdIdentityPlaceholderCitizenship, values: countries))
        index += 1
        
        let residence = state.detailsIntermediateState?.residence ?? .string(personalDetails?.residenceCountryCode)
        
        entries.append(InputDataEntry.selector(sectionId: sectionId, index: index, value: residence, error: pdErrors?[_id_residence], identifier: _id_residence, placeholder: L10n.secureIdIdentityPlaceholderResidence, values: countries))
        index += 1
        
        if let _ = relative {
            addRelativeIdentifier()
        }
        
        if case let .personalDetails(nativeName) = primary, nativeName {
            if let residence = residence.stringValue {
                entries.append(.sectionId(sectionId))
                sectionId += 1
                
                if state.configuration?.nativeLanguageByCountry[residence] != "en" {
                    
                    let country = countries.filter({$0.value.stringValue == residence}).first?.localized ?? residence
                    
                    var localizedDesc: String = ""
                    var localizedTitle: String = L10n.secureIdNameNativeHeaderEmpty
                    if let language = state.configuration?.nativeLanguageByCountry[residence] {
                        let key = "Passport.Language.\(language)"
                        let localizedKey = localizedString(key)
                        if localizedKey == key {
                            localizedDesc = L10n.secureIdNameNativeDescLanguage(country)
                        } else {
                            localizedTitle = L10n.secureIdNameNativeHeader(localizedKey.uppercased())
                            localizedDesc = L10n.secureIdNameNativeDescEmpty
                        }
                    }  else {
                        localizedDesc =  L10n.secureIdNameNativeDescLanguage(country)
                    }
                    
                    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: localizedTitle, color: theme.colors.grayText, detectBold: true))
                    index += 1
                    
                    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.firstNameNative ?? .string(personalDetails?.nativeName?.firstName ?? ""), error: pdErrors?[_id_first_name_native], identifier: _id_first_name_native, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderFirstName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderFirstName, filter: {$0}, limit: 255))
                    index += 1
                    
                    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.middleNameNative ?? .string(personalDetails?.nativeName?.middleName ?? ""), error: pdErrors?[_id_middle_name_native], identifier: _id_middle_name_native, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderMiddleName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderMiddleName, filter: {$0}, limit: 255))
                    index += 1
                    
                    entries.append(InputDataEntry.input(sectionId: sectionId, index: index, value: state.detailsIntermediateState?.lastNameNative ?? .string(personalDetails?.nativeName?.lastName ?? ""), error: pdErrors?[_id_last_name_native], identifier: _id_last_name_native, mode: .plain, placeholder: L10n.secureIdIdentityPlaceholderLastName, inputPlaceholder: L10n.secureIdIdentityInputPlaceholderLastName, filter: {$0}, limit: 255))
                    index += 1
                    
                    
                    
                    entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: localizedDesc, color: theme.colors.grayText, detectBold: true))
                    index += 1

                }
            }
        }
        
    }
    
    

    

   

    

    if let relative = relative {
        
        if primary == nil {
            addRelativeIdentifier()
        }
        
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
                        modernConfirm(for: mainWindow, account: state.account, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, information: L10n.secureIdConfirmDeleteDocument, successHandler: { _ in
                            updateState { current in
                                return current.withUpdatedFrontSide(nil, for: relative.valueKey)
                            }
                        })
                    })
                }))
                index += 1
            } else {
                entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_frontside, placeholder: isMainNotFront ? L10n.secureIdUploadTitleMainPage : L10n.secureIdUploadTitleFrontSide, description: relative.uploadFrontTitleText, icon: isMainNotFront ? theme.icons.passportPassport : (relative.valueKey == .driversLicense ? theme.icons.passportDriverLicense : theme.icons.passportIdCard), action: {
                    filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { files in
                        if let file = files?.first {
                            updateFrontMrz(file: file, relative: relative, updateState: updateState)
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
                                                let details = DetailsIntermediateState(firstName: .string(mrz.firstName), middleName: nil, lastName: .string(mrz.lastName), firstNameNative: nil, middleNameNative: nil, lastNameNative: nil, birthday: .date(birthDate[0], birthDate[1], birthDate[2]), citizenship: .string(mrz.issuingCountry), residence: current.detailsIntermediateState?.residence, gender: .gender(SecureIdGender.gender(from: mrz)), expiryDate: .date(expiryDate[0], expiryDate[1], expiryDate[2]), identifier: .string(mrz.documentNumber))
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
                    filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { paths in
                        if let path = paths?.first, let image = NSImage(contentsOfFile: path) {
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
        
        if relative.hasTranslation {
            
            entries.append(.sectionId(sectionId))
            sectionId += 1
            
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdTranslationHeader, color: theme.colors.grayText, detectBold: true))
            index += 1
            
            if let translationError = rErrors?[_id_translation] {
                entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: translationError.description, color: theme.colors.redUI, detectBold: true))
                index += 1
            }
            
            let translations = state.translations[relative.valueKey] ?? []
            
            var fileIndex: Int32 = 0
            
            if let accessContext = state.accessContext {
                for translation in translations {
                    let header = L10n.secureIdScanNumber(Int(fileIndex + 1))
                    entries.append(InputDataEntry.custom(sectionId: sectionId, index: index, value: .secureIdDocument(translation), identifier:  InputDataIdentifier("_translation_\(fileIndex)"), equatable: InputDataEquatable(translation), item: { initialSize, stableId -> TableRowItem in
                        return PassportDocumentRowItem(initialSize, account: state.account, document: SecureIdDocumentValue(document: translation, context: accessContext, stableId: stableId), error: rErrors?[translation.errorIdentifier], header: header, removeAction: { value in
                            updateState { current in
                                return current.withRemovedTranslation(value, for: relative.valueKey)
                            }
                        })
                    }))
                    fileIndex += 1
                    index += 1
                }
            }
            
            if translations.count < scansLimit {
                entries.append(InputDataEntry.dataSelector(sectionId: sectionId, index: index, value: .string(""), error: nil, identifier: _id_translation, placeholder: translations.count > 0 ? L10n.secureIdUploadAdditionalScan : L10n.secureIdUploadScan, description: nil, icon: nil, action: {
                    filePanel(with: photoExts, allowMultiple: true, for: mainWindow, completion: { files in
                        if let files = files {
                            let localFiles:[SecureIdVerificationDocument] = files.map({.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                            
                            updateState { current in
                                if localFiles.count + (current.translations[relative.valueKey] ?? []).count > scansLimit {
                                    alert(for: mainWindow, info: L10n.secureIdErrorScansLimit)
                                }
                                return current.withAppendTranslations(localFiles, for: relative.valueKey).withRemovedError(for: relative.valueKey, field: _id_translation)
                            }
                        }
                    })
                }))
                index += 1
            }
            
            
            entries.append(InputDataEntry.desc(sectionId: sectionId, index: index, text: L10n.secureIdTranslationDesc, color: theme.colors.grayText, detectBold: true))
            index += 1
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
    
    func updateEnabled(_ enabled: Bool, isVisible: Bool, action: @escaping(Bool)->Void) {
        self.item = PassportAcceptRowItem(authorize.frame.size, stableId: 0, enabled: enabled, action: {
            action(enabled)
        })
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
    private let secureIdConfigurationDisposable = MetaDisposable()
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
        return (form == nil ? L10n.navigationBack : "", form == nil ? #imageLiteral(resourceName: "Icon_NavigationBack").precomposed(theme.colors.blueIcon) : theme.icons.dismissPinned)
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
        
        let state:ValuePromise<PassportState> = ValuePromise(PassportState(account: account, peer: peer, tmpPwd: account.context.temporaryPassword, viewState: .plain), ignoreRepeated: true)
        
        let stateValue:Atomic<PassportState> = Atomic(value: PassportState(account: account, peer: peer, tmpPwd: account.context.temporaryPassword, viewState: .plain))
        
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
        
        
        
        let emailActivation = MetaDisposable()
        let saveValueDisposable = MetaDisposable()
        actionsDisposable.add(emailActivation)
        actionsDisposable.add(saveValueDisposable)
        
        let updateVerifyDocumentState: (Int64, SecureIdVerificationLocalDocumentState) -> Void = { id, state in
            updateState { current in
                return current.withUpdatedFileState(id: id, state: state)
            }
        }
        
        var checkPwd:((String) -> Void)?

        
        emailActivation.set((combineLatest(isKeyWindow.get() |> deliverOnPrepareQueue, Signal<Void, NoError>.single(Void()) |> delay(3.0, queue: prepareQueue) |> restart) |> mapToSignal { _ in return combineLatest(passwordVerificationData.get() |> take(1) |> deliverOnPrepareQueue, state.get() |> take(1) |> deliverOnPrepareQueue) }).start(next: { config, state in
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
                                        return accessSecureId(network: account.network, password: password) |> map { data in
                                            return (decryptedSecureIdForm(context: data.context, form: encryptedForm), data.context, data.settings)
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
                                            } |> `catch` {_ in return .complete()}
                                    } else {
                                        let signal = accessSecureId(network: account.network, password: password) |> mapToSignal { data in
                                            return getAllSecureIdValues(network: account.network)
                                                |> map { encryptedValues in
                                                    return decryptedAllSecureIdValues(context: data.context, encryptedValues: encryptedValues)
                                                }
                                                |> mapError {_ in return SecureIdAccessError.generic}
                                                |> map {($0, data.context, data.settings)}
                                            } |> deliverOnMainQueue
                                        
                                        return signal |> map { values, context, passwordSettings in
                                            updateState { current in
                                                var current = current.withRemovedValues()
                                                current = values.reduce(current, { current, value -> PassportState in
                                                    return current.withUpdatedValue(value)
                                                })
                                                return current.withUpdatedViewState(.settings).withUpdatedPasswordSettings(passwordSettings).withUpdatedAccessContext(context).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                                            }
                                             return Optional(config)
                                        } |> `catch` {_ in .complete()}
                                        
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
            if value.isEmpty {
                shake()
                return
            }
            if let encryptedForm = encryptedForm {
                checkPassword.set((accessSecureId(network: account.network, password: value) |> map { data in
                    return (decryptedSecureIdForm(context: data.context, form: encryptedForm), data.context, data.settings)
                    } |> deliverOnMainQueue).start(next: { form, context, settings in
                        
                        account.context.setTemporaryPwd(value)
                        
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
                                        case let .translationFile(hash):
                                            cErrors[InputDataIdentifier("file_\(hash.base64EncodedString())")] = InputDataValueError(description: eValue, target: .files)
                                        case .translationFiles:
                                            cErrors[_id_translation] = InputDataValueError(description: eValue, target: .files)
                                        case let .value(valueKey):
                                            if valueKey == value.value.key {
                                                cErrors[InputDataEmptyIdentifier] = InputDataValueError(description: eValue, target: .data)
                                            }
                                            //errors[valueKey] = [InputDataEmptyIdentifier : InputDataValueError(description: eValue, target: .data)]
                                            var bp:Int = 0
                                            bp += 1
                                        }
                                    }
                                    errors[value.value.key] = cErrors
                                }
                                current = current.withUpdatedErrors(errors)
                            }
                            return current.withUpdatedAccessContext(context).withUpdatedPasswordSettings(settings).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState)).withUpdatedPasswordError(nil)
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
                        case .passwordError(let error):
                            updateState { current in
                                switch error {
                                case .invalidPassword:
                                    return current.withUpdatedPasswordError(L10n.secureIdPasswordErrorInvalid)
                                case .limitExceeded:
                                    return current.withUpdatedPasswordError(L10n.secureIdPasswordErrorLimit)
                                default:
                                    return current.withUpdatedPasswordError(L10n.secureIdPasswordErrorInvalid)
                                }
                            }
                            shake()
                            
                        case .generic:
                            shake()
                        }
                        
                    }))
            } else {
                let signal = accessSecureId(network: account.network, password: value) |> mapToSignal { data in
                    return getAllSecureIdValues(network: account.network)
                        |> map { encryptedValues in
                            return decryptedAllSecureIdValues(context: data.context, encryptedValues: encryptedValues)
                        }
                        |> mapError {_ in return SecureIdAccessError.generic}
                        |> map {($0, data.context, data.settings)}
                } |> deliverOnMainQueue
                
                
                    
                checkPassword.set(signal.start(next: { values, context, passwordSettings in
                    
                    account.context.setTemporaryPwd(value)
                    
                    updateState { current in
                        var current = current.withRemovedValues()
                        current = values.reduce(current, { current, value -> PassportState in
                            return current.withUpdatedValue(value)
                        })
                        return current.withUpdatedViewState(.settings).withUpdatedPasswordSettings(passwordSettings).withUpdatedAccessContext(context).withUpdatedVerifyDocumentContext(SecureIdVerificationDocumentsContext(postbox: account.postbox, network: account.network, context: context, update: updateVerifyDocumentState))
                    }
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
            }
        }, requestField: { request, value, relativeValue, relative, editSettings in

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
                                return current.withUpdatedValue(value).withRemovedErrors(for: value.value.key).withUpdatedEmptyErrors(false)
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

            switch request.primary {
            case .address:
                var loadedData: AddressIntermediateState?
                let push:(SecureIdRequestedFormFieldValue, SecureIdRequestedFormFieldValue?, Bool) -> Void = { field, relative, hasMainField in
                    presentController(InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
                        return addressEntries(state, hasMainField: hasMainField, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in

                        if let _ = data[_id_delete] {
                            return .fail(.doSomething { next in
                                modernConfirm(for: mainWindow, account: account, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, header: L10n.telegramPassportController, information: relative == nil ? L10n.secureIdConfirmDeleteAddress : L10n.secureIdConfirmDeleteDocument, thridTitle: hasMainField ? L10n.secureIdConfirmDeleteAddress : nil, successHandler: { result in
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
                        
                        var translations:[SecureIdVerificationDocumentReference] = []
                        fileIndex = 0
                        while data[InputDataIdentifier("_translation_\(fileIndex)")] != nil {
                            let identifier = InputDataIdentifier("_translation_\(fileIndex)")
                            let value = data[identifier]!.secureIdDocument!
                            switch value {
                            case let .remote(reference):
                                translations.append(.remote(reference))
                            case let .local(local):
                                switch local.state {
                                case let .uploaded(file):
                                    translations.append(.uploaded(file))
                                case .uploading:
                                    fails[identifier] = .shake
                                }
                                
                            }
                            fileIndex += 1
                        }
                        
                        if let relative = relative, relative.hasTranslation, translations.isEmpty, editSettings == nil {
                            fails[_id_translation] = .shake
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
                                values.append(SecureIdValue.bankStatement(SecureIdBankStatementValue(verificationDocuments: verifiedDocuments, translations: translations)))
                            case .rentalAgreement:
                                values.append(SecureIdValue.rentalAgreement(SecureIdRentalAgreementValue(verificationDocuments: verifiedDocuments, translations: translations)))
                            case .utilityBill:
                                values.append(SecureIdValue.utilityBill(SecureIdUtilityBillValue(verificationDocuments: verifiedDocuments, translations: translations)))
                            case .passportRegistration:
                                values.append(SecureIdValue.passportRegistration(SecureIdPassportRegistrationValue(verificationDocuments: verifiedDocuments, translations: translations)))
                            case .temporaryRegistration:
                                values.append(SecureIdValue.temporaryRegistration(SecureIdTemporaryRegistrationValue(verificationDocuments: verifiedDocuments, translations: translations)))
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
                                    var i: Int = 0
                                    for file in verifiedDocuments {
                                        switch file {
                                        case let .remote(reference):
                                            if error.key == InputDataIdentifier("file_\(reference.fileHash.base64EncodedString())") {
                                                fails[InputDataIdentifier("_file_\(i)")] = .shake
                                            }
                                            i += 1
                                        default:
                                            break
                                        }
                                    }
                                    for file in translations {
                                        switch file {
                                        case let .remote(reference):
                                            if error.key == InputDataIdentifier("file_\(reference.fileHash.base64EncodedString())") {
                                                fails[InputDataIdentifier("_translation_\(i)")] = .shake
                                            }
                                            i += 1
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
                            var current = current
                            let address = AddressIntermediateState(data)
                            var errors = current.errors
                            
                            if let loadedData = loadedData {
                                let updatedErrors = loadedData.removeErrors(currentState: address, errors: errors[request.primary.valueKey])
                                errors[request.primary.valueKey] = updatedErrors
                                current = current.withUpdatedErrors(errors)
                            }
                            return current.withUpdatedAddressState(address)
                        }

                        return .fail(.none)
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedAddressState(nil).withUpdatedValues(current.values).withRemovedInputErrors()
                        }
                    }, didLoaded: { data in
                        loadedData = AddressIntermediateState(data)
                    }, identifier: "passport", backInvocation: { data, f in
                        if AddressIntermediateState(data) != loadedData {
                            confirm(for: mainWindow, header: L10n.secureIdDiscardChangesHeader, information: L10n.secureIdDiscardChangesText, okTitle: L10n.alertConfirmDiscard, successHandler: { _ in
                                 f(true)
                            })
                        } else {
                            f(true)
                        }
                        
                    }))
                }

                if let editSettings = editSettings {
                    var values:[ValuesSelectorValue<SecureIdRequestedFormFieldValue>] = []
                    for relative in relative {
                        values.append(ValuesSelectorValue<SecureIdRequestedFormFieldValue>(localized: editSettings.hasValue(relative) ? relative.descEdit : relative.descAdd, value: relative))
                    }
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(selected.value, selected.value == .address ? nil : selected.value, selected.value == .address)
                    }), for: mainWindow)
                } else if relative.count > 1 {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormFieldValue>] = relative.map({ValuesSelectorValue(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdResidentialAddress, onComplete: { selected in
                        filePanel(with: photoExts,for: mainWindow, completion: { files in
                            if let files = files {
                                push(request.primary, selected.value, request.fillPrimary)
                                let localFiles:[SecureIdVerificationDocument] = files.map({SecureIdVerificationDocument.local(SecureIdVerificationLocalDocument(id: arc4random64(), resource: LocalFileReferenceMediaResource(localFilePath: $0, randomId: arc4random64()), state: .uploading(0)))})
                                updateState { current in
                                    if localFiles.count + (current.files[selected.value.valueKey] ?? []).count > scansLimit {
                                        alert(for: mainWindow, info: L10n.secureIdErrorScansLimit)
                                    }
                                    return current.withAppendFiles(localFiles, for: selected.value.valueKey)
                                }
                            }
                        })
                    }), for: mainWindow)
                } else if relative.count == 1 {
                    push(request.primary, relative[0], request.fillPrimary)
                } else {
                    push(request.primary, nil, request.fillPrimary)
                }


            case .personalDetails:
                var loadedData:DetailsIntermediateState?
                let push:(SecureIdRequestedFormFieldValue, SecureIdRequestedFormFieldValue?, SecureIdRequestedFormFieldValue?) ->Void = { field, relative, primary in
                    presentController(InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
                        return identityEntries(state, primary: primary, relative: relative, updateState: updateState)
                    }, title: relative?.rawValue ?? field.rawValue, validateData: { data in


                        if let _ = data[_id_delete] {
                            return .fail(.doSomething { next in
                                modernConfirm(for: mainWindow, account: account, peerId: nil, accessory: theme.icons.confirmAppAccessoryIcon, header: L10n.telegramPassportController, information: primary != nil && relative != nil ? L10n.secureIdConfirmDeleteDocument : primary != nil ? L10n.secureIdDeleteConfirmPersonalDetails : L10n.secureIdConfirmDeleteDocument, thridTitle: primary != nil && relative != nil ? L10n.secureIdDeletePersonalDetails : nil, successHandler: { result in
                                    var keys: [SecureIdValueKey] = []
                                    if let relative = relative {
                                        keys.append(relative.valueKey)
                                    }
                                    switch result {
                                    case .basic:
                                        if primary != nil && relative == nil {
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
                        let middleName = data[_id_middle_name]?.stringValue ?? ""
                        let birthday = data[_id_birthday]?.secureIdDate
                        let countryCode = data[_id_country]?.stringValue ?? ""
                        let residence = data[_id_residence]?.stringValue ?? ""
                        let gender = data[_id_gender]?.gender
                        let identifier = data[_id_identifier]?.stringValue
                        
                        
                        let firstNameNative = data[_id_first_name_native]?.stringValue ?? ""
                        let middleNameNative = data[_id_middle_name_native]?.stringValue ?? ""
                        let lastNameNative = data[_id_last_name_native]?.stringValue ?? ""


                        let expiryDate = data[_id_expire_date]?.secureIdDate

                        let selfie = data[_id_selfie]?.secureIdDocument
                        let frontside = data[_id_frontside]?.secureIdDocument
                        let backside = data[_id_backside]?.secureIdDocument

                        var fails:[InputDataIdentifier : InputDataValidationFailAction] = [:]
                        if firstName.isEmpty, primary != nil {
                            fails[_id_first_name] = .shake
                        }
                        if lastName.isEmpty, primary != nil {
                            fails[_id_last_name] = .shake
                        }
                        if countryCode.isEmpty && primary != nil {
                            fails[_id_country] = .shake
                        }
                        if residence.isEmpty && primary != nil {
                            fails[_id_birthday] = .shake
                        }
                        if gender == nil && primary != nil {
                            fails[_id_gender] = .shake
                        }
                        if birthday == nil && primary != nil {
                            fails[_id_birthday] = .shake
                        }
                        
                        if let identifier = identifier, identifier.isEmpty {
                            fails[_id_identifier] = .shake
                        }

                        

                        if let relative = relative, relative.hasSelfie, selfie == nil, editSettings == nil {
                            fails[_id_selfie_scan] = .shake
                        }
                        
                        var fileIndex: Int = 0
                        var translations:[SecureIdVerificationDocumentReference] = []
                        while data[InputDataIdentifier("_translation_\(fileIndex)")] != nil {
                            let identifier = InputDataIdentifier("_translation_\(fileIndex)")
                            let value = data[identifier]!.secureIdDocument!
                            switch value {
                            case let .remote(reference):
                                translations.append(.remote(reference))
                            case let .local(local):
                                switch local.state {
                                case let .uploaded(file):
                                    translations.append(.uploaded(file))
                                case .uploading:
                                    fails[identifier] = .shake
                                }
                                
                            }
                            fileIndex += 1
                        }
                        
                        if let relative = relative, relative.hasTranslation, translations.isEmpty, editSettings == nil {
                            fails[_id_translation] = .shake
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

                        var nativeName: SecureIdPersonName? = nil
                        if let primary = primary, case let .personalDetails(isNativeName) = primary, isNativeName, data[_id_first_name_native] != nil {
                            if firstNameNative.isEmpty {
                                fails[_id_first_name_native] = .shake
                            }
                            if lastNameNative.isEmpty {
                                fails[_id_last_name_native] = .shake
                            }
                            if fails.isEmpty {
                                nativeName = SecureIdPersonName(firstName: firstNameNative, lastName: lastNameNative, middleName: middleNameNative)
                            }
                        }

                        if !fails.isEmpty {
                            return .fail(.fields(fails))
                        }

                       
                        

                        var values: [SecureIdValue] = []
                        if primary != nil {
                            let _birthday = birthday!
                            let _gender = gender!
                            values.append(SecureIdValue.personalDetails(SecureIdPersonalDetailsValue(latinName: SecureIdPersonName(firstName: firstName, lastName: lastName, middleName: middleName), nativeName: nativeName, birthdate: _birthday, countryCode: countryCode, residenceCountryCode: residence, gender: _gender)))
                        }

                        if let relative = relative {
                            let _identifier = identifier!
                            switch relative.valueKey {
                            case .idCard:
                                values.append(SecureIdValue.idCard(SecureIdIDCardValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], translations: translations, selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument, backSideDocument: backsideDocument)))
                            case .passport:
                                values.append(SecureIdValue.passport(SecureIdPassportValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], translations: translations, selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument)))
                            case .driversLicense:
                                values.append(SecureIdValue.driversLicense(SecureIdDriversLicenseValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], translations: translations, selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument, backSideDocument: backsideDocument)))
                            case .internalPassport:
                                values.append(SecureIdValue.internalPassport(SecureIdInternalPassportValue(identifier: _identifier, expiryDate: expiryDate, verificationDocuments: [], translations: translations, selfieDocument: selfieDocument ?? relativeValue?.selfieVerificationDocument, frontSideDocument: frontsideDocument)))

                            default:
                                break
                            }
                        }

                        let current = DetailsIntermediateState(data)
                        if let loadedData = loadedData {
                            var fails = loadedData.validateErrors(currentState: current, errors: _stateValue.errors(for: .personalDetails), relativeErrors: relative != nil ? _stateValue.errors(for: relative!.valueKey) : nil)
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
                                    var i: Int = 0
                                    for file in translations {
                                        switch file {
                                        case let .remote(reference):
                                            if error.key == InputDataIdentifier("file_\(reference.fileHash.base64EncodedString())") {
                                                fails[InputDataIdentifier("_translation_\(i)")] = .shake
                                            }
                                            i += 1
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
                            var current = current
                            let details = DetailsIntermediateState(data)
                            var errors = current.errors

                            if let loadedData = loadedData {
                                let updatedErrors = loadedData.removeErrors(currentState: details, errors: primary != nil ? errors[primary!.valueKey] : nil, relativeErrors: relative != nil ? errors[relative!.valueKey] : nil)
                                if let primary = primary {
                                    errors[primary.valueKey] = updatedErrors.errors
                                }
                                if let relative = relative {
                                    errors[relative.valueKey] = updatedErrors.relativeErrors
                                }
                                current = current.withUpdatedErrors(errors)
                            }
                            return current.withUpdatedDetailsState(details)
                        }
                        return .fail(.none)
                    }, afterDisappear: {
                        updateState { current in
                            return current.withUpdatedDetailsState(nil).withUpdatedValues(current.values).withRemovedInputErrors()
                        }
                    }, didLoaded: { data in
                        loadedData = DetailsIntermediateState(data)
                    }, identifier: "passport", backInvocation: { data, f in
                        if DetailsIntermediateState(data) != loadedData {
                            confirm(for: mainWindow, header: L10n.secureIdDiscardChangesHeader, information: L10n.secureIdDiscardChangesText, okTitle: L10n.alertConfirmDiscard, successHandler: { _ in
                                f(true)
                            })
                        } else {
                            f(true)
                        }
                        
                    }))
                }

                if let editSettings = editSettings {
                    var values:[ValuesSelectorValue<SecureIdRequestedFormFieldValue>] = []
                    for relative in relative {
                        values.append(ValuesSelectorValue<SecureIdRequestedFormFieldValue>(localized: editSettings.hasValue(relative) ? relative.descEdit : relative.descAdd, value: relative))
                    }
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        push(selected.value, selected.value.valueKey == .personalDetails ? nil : selected.value, selected.value.valueKey == .personalDetails ? .personalDetails(nativeName: true) : nil)
                    }), for: mainWindow)
                } else if relative.count > 1 {
                    let values:[ValuesSelectorValue<SecureIdRequestedFormFieldValue>] = relative.map({ValuesSelectorValue(localized: $0.rawValue, value: $0)})
                    showModal(with: ValuesSelectorModalController(values: values, selected: values[0], title: L10n.secureIdIdentityDocument, onComplete: { selected in
                        if let relativeValue = relativeValue, relativeValue.frontSideVerificationDocument != nil {
                            push(request.primary, selected.value, request.fillPrimary ? request.primary : nil)
                        } else {
                            filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { files in
                                if let file = files?.first {
                                    push(request.primary, selected.value, request.fillPrimary ? request.primary : nil)
                                    updateFrontMrz(file: file, relative: selected.value, updateState: updateState)
                                }
                            })
                        }
                    }), for: mainWindow)
                } else if relative.count == 1 {
                    if let relativeValue = relativeValue, relativeValue.frontSideVerificationDocument != nil {
                        push(request.primary, relative[0], request.fillPrimary ? request.primary : nil)
                    } else {
                        filePanel(with: photoExts, allowMultiple: false, for: mainWindow, completion: { files in
                            if let file = files?.first {
                                push(request.primary, relative[0], request.fillPrimary ? request.primary : nil)
                                updateFrontMrz(file: file, relative: relative[0], updateState: updateState)
                            }
                        })
                    }
                    
                } else {
                    push(request.primary, nil, request.fillPrimary ? request.primary : nil)
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
                    presentController(InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
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
                    var _payload: SecureIdPreparePhoneVerificationPayload?
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
                                                    
                                                    _payload = payload
                                                    
                                                    let validate: ([InputDataIdentifier : InputDataValue])->InputDataValidation = { data in
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
                                                    }
                                                    
                                                    presentController(InputDataController(dataSignal: combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
                                                        return confirmPhoneNumberEntries(state, phoneNumber: phone, updateState: updateState)
                                                    }, title: title, validateData: validate, updateDatas: { data in
                                                        if let payload = _payload, let code = data[_id_phone_code]?.stringValue {
                                                            switch payload.type {
                                                            case let .sms(length):
                                                                if code.length == length {
                                                                    return validate(data)
                                                                }
                                                            default:
                                                                break
                                                            }
                                                        }
                                                        return .fail(.none)
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
            promise.set(combineLatest(state.get() |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map { state, _ in
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
                    passwordVerificationData.set(.single(nil) |> then(updateTwoStepVerificationPassword(network: account.network, currentPassword: nil, updatedPassword: .password(password: password, hint: hint, email: email))
                        |> `catch` {_ in return .complete()}
                        |> mapToSignal { _ in
                            if email == nil {
                                updateState { current in
                                    return current.withUpdatedTmpPwd(password)
                                }
                                checkPwd?(password)
                            }
                            
                            return .single(configuration)
//                            return twoStepVerificationConfiguration(account: account) |> map { configuration in
//
//                                switch configuration {
//                                case .set:
//
//
//                                case .notSet:
//                                    break
//                                }
//                                return Optional(configuration)
//                            }
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
                |> `catch` {_ in .complete()}
                |> mapToSignal { _ in
                    updateState { current in
                        return current.withUpdatedPasswordSettings(nil)
                    }
                    return .single(TwoStepVerificationConfiguration.notSet(pendingEmailPattern: ""))
            }, for: mainWindow))
        }, authorize: { [weak self] enabled in
            
            if !enabled {
                updateState { current in
                    return current.withUpdatedEmptyErrors(true)
                }
                
                guard let `self` = self else {return}
                var scrollItem:TableRowItem? = nil
                
                self.genericView.tableView.enumerateItems(with: { item -> Bool in
                    if let stableId = item.stableId.base as? PassportEntryId {
                        switch stableId {
                        case .emptyFieldId:
                            scrollItem = item
                        default:
                            break
                        }
                        if scrollItem == nil, let item = item as? GeneralInteractedRowItem, let color = item.descLayout?.attributedString.attribute(NSAttributedStringKey.foregroundColor, at: 0, effectiveRange: nil) as? NSColor {
                            if color.argb == theme.colors.redUI.argb {
                                scrollItem = item
                            }
                        }
                    }
                    return scrollItem == nil
                })
                
                if let scrollItem = scrollItem {
                    self.genericView.tableView.scroll(to: TableScrollState.top(id: scrollItem.stableId, innerId: nil, animated: true, focus: true, inset: 0), inset: NSEdgeInsets(), true)
                }
                
                return
            }
            
            
            if let inAppRequest = inAppRequest, let encryptedForm = encryptedForm {
                authorizeDisposable.set(showModalProgress(signal: state.get() |> take(1) |> mapError { _ in return GrantSecureIdAccessError.generic} |> mapToSignal { state -> Signal<Void, GrantSecureIdAccessError> in
                    
                    var values:[SecureIdValueWithContext] = []
                    
                    let requestedFields = encryptedForm.requestedFields.map { value -> SecureIdRequestedFormField in
                        switch value {
                        case let .just(key):
                            switch key {
                            case .email, .phone, .personalDetails, .address:
                                return value
                            default:
                                return .oneOf([key])
                            }
                        default:
                            return value
                        }
                    }
                    
                    for field in requestedFields {
                        switch field {
                        case let .just(field):
                            if let value = state.values.filter({$0.value.key == field.valueKey}).first {
                                values.append(value)
                            }
                        case let .oneOf(fields):
                            if fields.count == 1 {
                                if let value = state.values.filter({$0.value.key == fields[0].valueKey}).first {
                                    values.append(value)
                                }
                            } else {
                                let field = fields.filter({ field in
                                    return state.searchValue(field.valueKey) != nil
                                }).first
                                if let field = field, let value = state.values.filter({$0.value.key == field.valueKey}).first {
                                    values.append(value)
                                }
                            }
                        }
                    }
                    
                    return grantSecureIdAccess(network: account.network, peerId: inAppRequest.peerId, publicKey: inAppRequest.publicKey, scope: inAppRequest.scope, opaquePayload: inAppRequest.isModern ? Data() : inAppRequest.nonce, opaqueNonce: inAppRequest.isModern ? inAppRequest.nonce : Data(), values: values, requestedFields: encryptedForm.requestedFields)
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
                let promise:Promise<[InputDataEntry]> = Promise()
                promise.set(combineLatest(Signal<[InputDataEntry], NoError>.single(recoverEmailEntries(emailPattern: emailPattern)) |> deliverOnPrepareQueue, appearanceSignal |> deliverOnPrepareQueue) |> map {$0.0})
                presentController(InputDataController(dataSignal: promise.get(), title: L10n.secureIdRecoverPassword, validateData: { data -> InputDataValidation in

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
        
        
        checkPwd = { value in
            arguments.checkPassword((value, {}))
        }
        

     
        
        
        let botPeerSignal = form != nil ? account.postbox.loadedPeerWithId(form!.peerId) |> map {Optional($0)} |> deliverOnPrepareQueue : Signal<Peer?, NoError>.single(nil)
        
        let signal: Signal<(TableUpdateTransition, Bool, Bool), NoError> = combineLatest(appearanceSignal |> deliverOnPrepareQueue, formValue.get() |> deliverOnPrepareQueue, passwordVerificationData.get() |> deliverOnPrepareQueue, state.get() |> deliverOnPrepareQueue, botPeerSignal) |> map { appearance, form, passwordData, state, peer in

            let (entries, enabled) = passportEntries(encryptedForm: form.0, form: form.1, peer: peer, passwordData: passwordData, state: state)

            let converted = entries.map {AppearanceWrapperEntry(entry: $0, appearance: appearance)}
            return (prepareTransition(left: previous.swap(converted), right: converted, initialSize: initialSize.modify{$0}, arguments: arguments), enabled, form.1 != nil)
        } |> deliverOnMainQueue |> afterDisposed {
            actionsDisposable.dispose()
        }
        
        if let pwd = account.context.temporaryPassword {
            actionsDisposable.add((passwordVerificationData.get() |> filter {$0 != nil} |> take(1) |> deliverOnMainQueue).start(next: { _ in
                arguments.checkPassword((pwd, {
                    account.context.resetTemporaryPwd()
                    updateState { current in
                        return current.withUpdatedTmpPwd(nil)
                    }
                }))
            }))
        }
        
        passwordVerificationData.set(.single(nil) |> then(twoStepVerificationConfiguration(account: account) |> map {Optional($0)}))

        
        secureIdConfigurationDisposable.set(secureIdConfiguration(postbox: account.postbox, network: account.network).start(next: { configuration in
            updateState { current in
                return current.withUpdatedConfiguration(configuration)
            }
        }))
        
        disposable.set(signal.start(next: { [weak self] transition, enabled, isVisible in
                        guard let `self` = self else {return}
            self.genericView.tableView.merge(with: transition)
            self.genericView.updateEnabled(enabled, isVisible: isVisible, action: arguments.authorize)
            
            self.readyOnce()
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
            confirm(for: mainWindow, information: L10n.secureIdConfirmCancel, okTitle: L10n.alertConfirmStop, successHandler: { [weak self] _ in
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
        secureIdConfigurationDisposable.dispose()
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
