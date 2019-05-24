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
    case search(InputDataIdentifier)
    case loading
    case sectionId(Int32)
    var hashValue: Int {
        return 0
    }
    
    var identifier: InputDataIdentifier? {
        switch self {
        case let .input(identifier), let .selector(identifier), let .dataSelector(identifier), let .dateSelector(identifier), let .general(identifier), let .custom(identifier), let .search(identifier):
            return identifier
        default:
            return nil
        }
    }
}


enum InputDataInputMode {
    case plain
    case secure
}



public protocol _HasCustomInputDataEquatableRepresentation {
    func _toCustomInputDataEquatable() -> InputDataEquatable?
}

internal protocol _InputDataEquatableBox {
    var _typeID: ObjectIdentifier { get }
    func _unbox<T : Equatable>() -> T?

    func _isEqual(to: _InputDataEquatableBox) -> Bool?
    
    var _base: Any { get }
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool
}

internal struct _ConcreteEquatableBox<Base : Equatable> : _InputDataEquatableBox {
    internal var _baseEquatable: Base
    
    internal init(_ base: Base) {
        self._baseEquatable = base
    }
    
    
    internal var _typeID: ObjectIdentifier {
        return ObjectIdentifier(type(of: self))
    }
    
    internal func _unbox<T : Equatable>() -> T? {
        return (self as _InputDataEquatableBox as? _ConcreteEquatableBox<T>)?._baseEquatable
    }
    
    internal func _isEqual(to rhs: _InputDataEquatableBox) -> Bool? {
        if let rhs: Base = rhs._unbox() {
            return _baseEquatable == rhs
        }
        return nil
    }

    internal var _base: Any {
        return _baseEquatable
    }
    
    internal
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        guard let value = _baseEquatable as? T else { return false }
        result.initialize(to: value)
        return true
    }
}


public struct InputDataEquatable {
    internal var _box: _InputDataEquatableBox
    internal var _usedCustomRepresentation: Bool
    

    public init<H : Equatable>(_ base: H) {
        if let customRepresentation =
            (base as? _HasCustomInputDataEquatableRepresentation)?._toCustomInputDataEquatable() {
            self = customRepresentation
            self._usedCustomRepresentation = true
            return
        }
        
        self._box = _ConcreteEquatableBox(base)
        self._usedCustomRepresentation = false
    }
    
    internal init<H : Equatable>(_usingDefaultRepresentationOf base: H) {
        self._box = _ConcreteEquatableBox(base)
        self._usedCustomRepresentation = false
    }
    
    public var base: Any {
        return _box._base
    }
    internal
    func _downCastConditional<T>(into result: UnsafeMutablePointer<T>) -> Bool {
        // Attempt the downcast.
        if _box._downCastConditional(into: result) { return true }
        
    
        
        return false
    }
}

extension InputDataEquatable : Equatable {
    public static func == (lhs: InputDataEquatable, rhs: InputDataEquatable) -> Bool {
        if let result = lhs._box._isEqual(to: rhs._box) { return result }
        
        return false
    }
}

extension InputDataEquatable : CustomStringConvertible {
    public var description: String {
        return String(describing: base)
    }
}

extension InputDataEquatable : CustomDebugStringConvertible {
    public var debugDescription: String {
        return "InputDataEquatable(" + String(reflecting: base) + ")"
    }
}

extension InputDataEquatable : CustomReflectable {
    public var customMirror: Mirror {
        return Mirror(
            self,
            children: ["value": base])
    }
}




public // COMPILER_INTRINSIC
func _convertToInputDataEquatable<H : Equatable>(_ value: H) -> InputDataEquatable {
    return InputDataEquatable(value)
}

internal func _convertToInputDataEquatableIndirect<H : Equatable>(
    _ value: H,
    _ target: UnsafeMutablePointer<InputDataEquatable>
    ) {
    target.initialize(to: InputDataEquatable(value))
}

internal func _InputDataEquatableDownCastConditionalIndirect<T>(
    _ value: UnsafePointer<InputDataEquatable>,
    _ target: UnsafeMutablePointer<T>
    ) -> Bool {
    return value.pointee._downCastConditional(into: target)
}


struct InputDataInputPlaceholder : Equatable {
    let placeholder: String?
    let drawBorderAfterPlaceholder: Bool
    let icon: CGImage?
    let action: (()-> Void)?
    let hasLimitationText: Bool
    let rightResoringImage: CGImage?
    init(_ placeholder: String? = nil, icon: CGImage? = nil, drawBorderAfterPlaceholder: Bool = false, hasLimitationText: Bool = false, rightResoringImage: CGImage? = nil, action: (()-> Void)? = nil) {
        self.drawBorderAfterPlaceholder = drawBorderAfterPlaceholder
        self.hasLimitationText = hasLimitationText
        self.placeholder = placeholder
        self.rightResoringImage = rightResoringImage
        self.icon = icon
        self.action = action
    }
    
    static func ==(lhs: InputDataInputPlaceholder, rhs: InputDataInputPlaceholder) -> Bool {
        return lhs.placeholder == rhs.placeholder && lhs.icon === rhs.icon && lhs.drawBorderAfterPlaceholder == rhs.drawBorderAfterPlaceholder
    }
}


final class InputDataGeneralData : Equatable {
    let name: String
    let color: NSColor
    let icon: CGImage?
    let type: GeneralInteractedType
    let description: String?
    let action: (()->Void)?
    init(name: String, color: NSColor, icon: CGImage? = nil, type: GeneralInteractedType = .none, description: String? = nil, action: (()->Void)? = nil) {
        self.name = name
        self.color = color
        self.icon = icon
        self.type = type
        self.description = description
        self.action = action
    }
    
    static func ==(lhs: InputDataGeneralData, rhs: InputDataGeneralData) -> Bool {
        return lhs.name == rhs.name && lhs.icon === rhs.icon && lhs.color.hexString == rhs.color.hexString && lhs.type == rhs.type && lhs.description == rhs.description
    }
}

enum InputDataEntry : Identifiable, Comparable {
    case desc(sectionId: Int32, index: Int32, text: GeneralRowTextType, color: NSColor, detectBold: Bool)
    case input(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, mode: InputDataInputMode, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, filter:(String)->String, limit: Int32)
    case general(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, data: InputDataGeneralData)
    case dateSelector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String)
    case selector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String, values:[ValuesSelectorValue<InputDataValue>])
    case dataSelector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String, description: String?, icon: CGImage?, action:()->Void)
    case custom(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, equatable: InputDataEquatable?, item:(NSSize, InputDataEntryId)->TableRowItem)
    case search(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, update:(SearchState)->Void)
    case loading
    case sectionId(Int32)
    
    var stableId: InputDataEntryId {
        switch self {
        case let .desc(_, index, _, _, _):
            return .desc(index)
        case let .input(_, _, _, _, identifier, _, _, _, _, _):
            return .input(identifier)
        case let .general(_, _, _, _, identifier, _):
            return .general(identifier)
        case let .selector(_, _, _, _, identifier, _, _):
            return .selector(identifier)
        case let .dataSelector(_, _, _, _, identifier, _, _, _, _):
            return .dataSelector(identifier)
        case let .dateSelector(_, _, _, _, identifier, _):
            return .dateSelector(identifier)
        case let .custom(_, _, _, identifier, _, _):
            return .custom(identifier)
        case let .search(_, _, _, identifier, _):
            return .custom(identifier)
        case let .sectionId(index):
            return .sectionId(index)
        case .loading:
            return .loading
        }
    }
    
    var stableIndex: Int32 {
        switch self {
        case let .desc(_, index, _, _, _):
            return index
        case let .input(_, index, _, _, _, _, _, _, _, _):
            return index
        case let .general(_, index, _, _, _, _):
            return index
        case let .selector(_, index, _, _, _, _, _):
            return index
        case let .dateSelector(_, index, _, _, _, _):
            return index
        case let .dataSelector(_, index, _, _, _, _, _, _, _):
            return index
        case let .custom(_, index, _, _, _, _):
            return index
        case let .search(_, index, _, _, _):
            return index
        case .loading:
            return 0
        case .sectionId:
            fatalError()
        }
    }
    
    var sectionIndex: Int32 {
        switch self {
        case let .desc(index, _, _, _, _):
            return index
        case let .input(index, _, _, _, _, _, _, _, _, _):
            return index
        case let .selector(index, _, _, _, _, _, _):
            return index
        case let .general(index, _, _, _, _, _):
            return index
        case let .dateSelector(index, _, _, _, _, _):
            return index
        case let .dataSelector(index, _, _, _, _, _, _, _, _):
            return index
        case let .custom(index, _, _, _, _, _):
            return index
        case let .search(index, _, _, _, _):
            return index
        case .loading:
            return 0
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
        case let .desc(_, _, text, color, detectBold):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: detectBold, textColor: color)
        case let .custom(_, _, _, _, _, item):
            return item(initialSize, stableId)
        case let .selector(_, _, value, error, _, placeholder, values):
            return InputDataDataSelectorRowItem(initialSize, stableId: stableId, value: value, error: error, placeholder: placeholder, updated: arguments.dataUpdated, values: values)
        case let .dataSelector(_, _, _, error, _, placeholder, description, icon, action):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: placeholder, icon: icon, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.blueUI), description: description, type: .none, action: action, error: error)
        case let .general(_, _, value, error, identifier, data):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: data.name, icon: data.icon, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: data.color), description: data.description, type: data.type, action: {
                data.action != nil ? data.action?() : arguments.select((identifier, value))
            }, error: error)
        case let .dateSelector(_, _, value, error, _, placeholder):
            return InputDataDateRowItem(initialSize, stableId: stableId, value: value, error: error, updated: arguments.dataUpdated, placeholder: placeholder)
        case let .input(_, _, value, error, _, mode, placeholder, inputPlaceholder, filter, limit: limit):
            return InputDataRowItem(initialSize, stableId: stableId, mode: mode, error: error, currentText: value.stringValue ?? "", placeholder: placeholder, inputPlaceholder: inputPlaceholder, filter: filter, updated: arguments.dataUpdated, limit: limit)
        case .loading:
            return SearchEmptyRowItem.init(initialSize, stableId: stableId, isLoading: true)
        case let .search(_, _, value, _, update):
            return SearchRowItem(initialSize, stableId: stableId, searchInteractions: SearchInteractions({ state, _ in
                update(state)
            }, { state in
                update(state)
            }), inset: NSEdgeInsets(left: 10,right: 10, top: 10, bottom: 10))
        }
    }
}

func <(lhs: InputDataEntry, rhs: InputDataEntry) -> Bool {
    return lhs.index < rhs.index
}

func ==(lhs: InputDataEntry, rhs: InputDataEntry) -> Bool {
    switch lhs {
    case let .desc(sectionId, index, text, lhsColor, detectBold):
        if case .desc(sectionId, index, text, let rhsColor, detectBold) = rhs {
            return lhsColor == rhsColor
        } else {
            return false
        }
    case let .input(sectionId, index, lhsValue, lhsError, identifier, mode, placeholder, inputPlaceholder, _, limit):
        if case .input(sectionId, index, let rhsValue, let rhsError, identifier, mode, placeholder, inputPlaceholder, _, limit) = rhs {
            return lhsValue == rhsValue && lhsError == rhsError
        } else {
            return false
        }
    case let .general(sectionId, index, lhsValue, lhsError, identifier, data):
        if case .general(sectionId, index, let rhsValue, let rhsError, identifier, data) = rhs {
            return lhsValue == rhsValue && lhsError == rhsError
        } else {
            return false
        }
    case let .selector(sectionId, index, lhsValue, lhsError, identifier, placeholder, lhsValues):
        if case .selector(sectionId, index, let rhsValue, let rhsError, identifier, placeholder, let rhsValues) = rhs {
            return lhsValues == rhsValues && lhsValue == rhsValue && lhsError == rhsError
        } else {
            return false
        }
    case let .dateSelector(sectionId, index, lhsValue, lhsError, identifier, placeholder):
        if case .dateSelector(sectionId, index, let rhsValue, let rhsError, identifier, placeholder) = rhs {
            return lhsValue == rhsValue && lhsError == rhsError
        } else {
            return false
        }
    case let .dataSelector(sectionId, index, lhsValue, lhsError, identifier, placeholder, description, lhsIcon, _):
        if case .dataSelector(sectionId, index, let rhsValue, let rhsError, identifier, placeholder, description, let rhsIcon, _) = rhs {
            return lhsValue == rhsValue && lhsError == rhsError && lhsIcon == rhsIcon
        } else {
            return false
        }
    case let .custom(sectionId, index, value, identifier, lhsEquatable, _):
        if case .custom(sectionId, index, value, identifier, let rhsEquatable, _) = rhs {
            return lhsEquatable == rhsEquatable
        } else {
            return false
        }
    case let .search(sectionId, index, value, identifier, _):
        if case .search(sectionId, index, value, identifier, _) = rhs {
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
    case .loading:
        if case .loading = rhs {
            return true
        } else {
            return false
        }
    }
}

let InputDataEmptyIdentifier = InputDataIdentifier("")

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
    case none
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
    case .none:
        if case .none = rhs {
            return true
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
    case navigationBackWithPushAnimation
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
    case none
    var isSuccess: Bool {
        switch self {
        case .success:
            return true
        case .fail, .none:
            return false
            
        }
    }
}




enum InputDoneValue : Equatable {
    case enabled(String)
    case disabled(String)
    case invisible
    case loading
}
