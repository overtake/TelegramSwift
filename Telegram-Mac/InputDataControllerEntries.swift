//
//  InputDataControllerEntries.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCoreMac
import SwiftSignalKitMac

enum InputDataEntryId : Hashable {
    case desc(Int32)
    case input(InputDataIdentifier)
    case general(InputDataIdentifier)
    case selector(InputDataIdentifier)
    case dataSelector(InputDataIdentifier)
    case dateSelector(InputDataIdentifier)
    case custom(InputDataIdentifier)
    case sectionId(Int32)
    var hashValue: Int {
        return 0
    }
    
    var identifier: InputDataIdentifier? {
        switch self {
        case let .input(identifier), let .selector(identifier), let .dataSelector(identifier), let .dateSelector(identifier), let .general(identifier), let .custom(identifier):
            return identifier
        default:
            return nil
        }
    }
}

func ==(lhs: InputDataEntryId, rhs: InputDataEntryId) -> Bool {
    switch lhs {
    case let .desc(id):
        if case .desc(id) = rhs {
            return true
        } else {
            return false
        }
    case let .input(id):
        if case .input(id) = rhs {
            return true
        } else {
            return false
        }
    case let .general(id):
        if case .general(id) = rhs {
            return true
        } else {
            return false
        }
    case let .selector(id):
        if case .selector(id) = rhs {
            return true
        } else {
            return false
        }
    case let .dataSelector(id):
        if case .dataSelector(id) = rhs {
            return true
        } else {
            return false
        }
    case let .dateSelector(id):
        if case .dateSelector(id) = rhs {
            return true
        } else {
            return false
        }
    case let .custom(id):
        if case .custom(id) = rhs {
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

enum InputDataInputMode {
    case plain
    case secure
}

enum InputDataEntry : Identifiable, Comparable {
    case desc(sectionId: Int32, index: Int32, text: String)
    case input(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, mode: InputDataInputMode, placeholder: String, inputPlaceholder: String, filter:(String)->String, limit: Int32)
    case general(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, name: String, color: NSColor, type: GeneralInteractedType)
    case dateSelector(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, placeholder: String)
    case selector(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, placeholder: String, values:[ValuesSelectorValue<InputDataValue>])
    case dataSelector(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, placeholder: String, action:()->Void)
    case custom(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, item:(NSSize, InputDataEntryId)->TableRowItem)
    case sectionId(Int32)
    
    var stableId: InputDataEntryId {
        switch self {
        case let .desc(_, index, _):
            return .desc(index)
        case let .input(_, _, _, identifier, _, _, _, _, _):
            return .input(identifier)
        case let .general(_, _, _, identifier, _, _, _):
            return .general(identifier)
        case let .selector(_, _, _, identifier, _, _):
            return .selector(identifier)
        case let .dataSelector(_, _, _, identifier, _, _):
            return .dataSelector(identifier)
        case let .dateSelector(_, _, _, identifier, _):
            return .dateSelector(identifier)
        case let .custom(_, index, _, identifier, _):
            return .custom(identifier)
        case let .sectionId(index):
            return .sectionId(index)
        }
    }
    
    var stableIndex: Int32 {
        switch self {
        case let .desc(_, index, _):
            return index
        case let .input(_, index, _, _, _, _, _, _, _):
            return index
        case let .general(_, index, _, _, _, _, _):
            return index
        case let .selector(_, index, _, _, _, _):
            return index
        case let .dateSelector(_, index, _, _, _):
            return index
        case let .dataSelector(_, index, _, _, _, _):
            return index
        case let .custom(_, index, _, _, _):
            return index
        case .sectionId:
            fatalError()
        }
    }
    
    var sectionIndex: Int32 {
        switch self {
        case let .desc(index, _, _):
            return index
        case let .input(index, _, _, _, _, _, _, _, _):
            return index
        case let .selector(index, _, _, _, _, _):
            return index
        case let .general(index, _, _, _, _, _, _):
            return index
        case let .dateSelector(index, _, _, _, _):
            return index
        case let .dataSelector(index, _, _, _, _, _):
            return index
        case let .custom(index, _, _, _, _):
            return index
        case .sectionId:
            fatalError()
        }
    }
    
    var index: Int32 {
        switch self {
        case let .sectionId(sectionId):
            return (sectionId + 1) * 1000 - sectionId
        default:
            return (sectionIndex * 1000) + stableIndex
        }
    }
    
    func item(arguments: InputDataArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case .sectionId:
            return GeneralRowItem(initialSize, height: 20, stableId: stableId)
        case let .desc(_, _, text):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text)
        case let .custom(_, _, _, _, item):
            return item(initialSize, stableId)
        case let .selector(_, _, value, _, placeholder, values):
            return InputDataDataSelectorRowItem(initialSize, stableId: stableId, placeholder: placeholder, value: value, updated: arguments.dataUpdated, values: values)
        case let .dataSelector(_, _, value, _, placeholder, action):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: placeholder, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.blueUI), type: .none, action: action)
        case let .general(_, _, value, identifier, name, color, type):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: name, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: color), type: type, action: {
                arguments.select((identifier, value))
            })
        case let .dateSelector(_, _, value, _, placeholder):
            return InputDataDateRowItem(initialSize, stableId: stableId, value: value, updated: arguments.dataUpdated, placeholder: placeholder)
        case let .input(_, _, value, _, mode, placeholder, inputPlaceholder, filter, limit: limit):
            return InputDataRowItem(initialSize, stableId: stableId, mode: mode, currentText: value.stringValue ?? "", placeholder: placeholder, inputPlaceholder: inputPlaceholder, filter: filter, updated: arguments.dataUpdated, limit: limit)
        }
    }
}

func <(lhs: InputDataEntry, rhs: InputDataEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs: InputDataEntry, rhs: InputDataEntry) -> Bool {
    switch lhs {
    case let .desc(sectionId, index, text):
        if case .desc(sectionId, index, text) = rhs {
            return true
        } else {
            return false
        }
    case let .input(sectionId, index, lhsValue, identifier, mode, placeholder, inputPlaceholder, _, limit):
        if case .input(sectionId, index, let rhsValue, identifier, mode, placeholder, inputPlaceholder, _, limit) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .general(sectionId, index, lhsValue, identifier, name, color, type):
        if case .general(sectionId, index, let rhsValue, identifier, name, color, type) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .selector(sectionId, index, lhsValue, identifier, placeholder, lhsValues):
        if case .selector(sectionId, index, let rhsValue, identifier, placeholder, let rhsValues) = rhs {
            return lhsValues == rhsValues && lhsValue == rhsValue
        } else {
            return false
        }
    case let .dateSelector(sectionId, index, lhsValue, identifier, placeholder):
        if case .dateSelector(sectionId, index, let rhsValue, identifier, placeholder) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .dataSelector(sectionId, index, lhsValue, identifier, placeholder, _):
        if case .dataSelector(sectionId, index, let rhsValue, identifier, placeholder, _) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .custom(sectionId, index, value, identifier, _):
        if case .custom(sectionId, index, value, identifier, _) = rhs {
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



struct InputDataIdentifier : Hashable {
    let identifier: String
    init(_ identifier: String) {
        self.identifier = identifier
    }
    var hashValue: Int {
        return identifier.hashValue
    }
}

func ==(lhs: InputDataIdentifier, rhs: InputDataIdentifier) -> Bool {
    return lhs.identifier == rhs.identifier
}

enum InputDataValue : Equatable {
    case string(String?)
    case date(Int32?, Int32?, Int32?)
    case gender(SecureIdGender?)
    case secureIdDocument(SecureIdVerificationDocument)
    var stringValue: String? {
        switch self {
        case let .string(value):
            return value
        default:
            return nil
        }
    }
    
    var secureIdDocument: SecureIdVerificationDocument? {
        switch self {
        case let .secureIdDocument(document):
            return document
        default:
            return nil
        }
    }
    
    var gender: SecureIdGender? {
        switch self {
        case let .gender(gender):
            return gender
        default:
            return nil
        }
    }
}

func ==(lhs: InputDataValue, rhs: InputDataValue) -> Bool {
    switch lhs {
    case let .string(lhsValue):
        if case let .string(rhsValue) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .gender(lhsValue):
        if case let .gender(rhsValue) = rhs {
            return lhsValue == rhsValue
        } else {
            return false
        }
    case let .secureIdDocument(lhsValue):
        if case let .secureIdDocument(rhsValue) = rhs {
            return lhsValue.isEqual(to: rhsValue)
        } else {
            return false
        }
    case let .date(lhsDay, lhsMonth, lhsYear):
        if case let .date(rhsDay, rhsMonth,rhsYear) = rhs {
            return lhsDay == rhsDay && lhsMonth == rhsMonth && lhsYear == rhsYear
        } else {
            return false
        }
    }
}

enum InputDataValidationFailAction {
    case shake
}

enum InputDataValidationBehaviour {
    case navigationBack
    case custom(()->Void)
}

enum InputDataFailResult {
    case alert(String)
    case doSomething(next: (@escaping(InputDataValidation)->Void) -> Void)
    case textAfter(String, InputDataIdentifier)
    case fields([InputDataIdentifier: InputDataValidationFailAction])
    case none
}

enum InputDataValidation {
    case success(InputDataValidationBehaviour)
    case fail(InputDataFailResult)
    
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .fail:
            return false
        }
    }
}

