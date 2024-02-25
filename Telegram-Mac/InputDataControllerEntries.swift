//
//  InputDataControllerEntries.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 21/03/2018.
//  Copyright © 2018 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import TelegramCore

import SwiftSignalKit

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


enum InputDataInputMode : Equatable {
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


struct InputDataComparableIndex : Comparable {
    let data: Any
    let compare:(Any, Any)->Bool
    let equatable:(Any, Any)->Bool

    static func <(lhs: InputDataComparableIndex, rhs: InputDataComparableIndex) -> Bool {
        return lhs.compare(lhs.data, rhs.data)
    }
    static func ==(lhs: InputDataComparableIndex, rhs: InputDataComparableIndex) -> Bool {
        return lhs.equatable(lhs.data, rhs.data)
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
    let insets: NSEdgeInsets
    init(_ placeholder: String? = nil, icon: CGImage? = nil, drawBorderAfterPlaceholder: Bool = false, hasLimitationText: Bool = false, insets: NSEdgeInsets = NSEdgeInsets(), action: (()-> Void)? = nil) {
        self.drawBorderAfterPlaceholder = drawBorderAfterPlaceholder
        self.hasLimitationText = hasLimitationText
        self.placeholder = placeholder
        self.icon = icon
        self.action = action
        self.insets = insets
    }
    
    static func ==(lhs: InputDataInputPlaceholder, rhs: InputDataInputPlaceholder) -> Bool {
        return lhs.placeholder == rhs.placeholder && lhs.icon === rhs.icon && lhs.drawBorderAfterPlaceholder == rhs.drawBorderAfterPlaceholder && lhs.insets == rhs.insets
    }
}


final class InputDataGeneralData : Equatable {
    
    

    
    let name: String
    let nameAttributed: NSAttributedString?
    let color: NSColor
    let icon: CGImage?
    let type: GeneralInteractedType
    let viewType: GeneralViewType
    let description: String?
    let action: (()->Void)?
    let disabledAction:(()->Void)?
    let switchAction: (()->Void)?
    let descClick:(()->Void)?
    let enabled: Bool
    let justUpdate: Int64?
    let menuItems:(()->[ContextMenuItem])?
    let theme: GeneralRowItem.Theme?
    let disableBorder: Bool
    let descTextColor: NSColor?
    let afterNameImage: CGImage?
    init(name: String, color: NSColor, icon: CGImage? = nil, type: GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, enabled: Bool = true, description: String? = nil, descTextColor: NSColor? = nil, justUpdate: Int64? = nil, action: (()->Void)? = nil, switchAction: (()->Void)? = nil, disabledAction: (()->Void)? = nil, menuItems:(()->[ContextMenuItem])? = nil, descClick: (()->Void)? = nil, theme: GeneralRowItem.Theme? = nil, disableBorder: Bool = false, nameAttributed: NSAttributedString? = nil, afterNameImage: CGImage? = nil) {
        self.name = name
        self.color = color
        self.icon = icon
        self.type = type
        self.viewType = viewType
        self.description = description
        self.action = action
        self.descClick = descClick
        self.switchAction = switchAction
        self.enabled = enabled
        self.justUpdate = justUpdate
        self.disabledAction = disabledAction
        self.menuItems = menuItems
        self.theme = theme
        self.disableBorder = disableBorder
        self.nameAttributed = nameAttributed
        self.descTextColor = descTextColor
        self.afterNameImage = afterNameImage
    }
    
    static func ==(lhs: InputDataGeneralData, rhs: InputDataGeneralData) -> Bool {
        return lhs.name == rhs.name && lhs.icon === rhs.icon && lhs.color.hexString == rhs.color.hexString && lhs.type == rhs.type && lhs.description == rhs.description && lhs.viewType == rhs.viewType && lhs.enabled == rhs.enabled && lhs.justUpdate == rhs.justUpdate && lhs.theme == rhs.theme && lhs.disableBorder == rhs.disableBorder && lhs.nameAttributed == rhs.nameAttributed && lhs.descTextColor == rhs.descTextColor && lhs.afterNameImage == rhs.afterNameImage
    }
}

final class InputDataTextInsertAnimatedViewData : NSObject {
    let context: AccountContext
    let file: TelegramMediaFile
    init(context: AccountContext, file: TelegramMediaFile) {
        self.context = context
        self.file = file
    }
    static func == (lhs: InputDataTextInsertAnimatedViewData, rhs: InputDataTextInsertAnimatedViewData) -> Bool {
        return lhs.file == rhs.file
    }
    static var attributeKey: NSAttributedString.Key {
        return NSAttributedString.Key("InputDataTextInsertAnimatedDataKey")
    }
}

struct InputDataGeneralTextRightData : Equatable {
    static func == (lhs: InputDataGeneralTextRightData, rhs: InputDataGeneralTextRightData) -> Bool {
        return lhs.text == rhs.text && lhs.isLoading == rhs.isLoading && lhs.update == rhs.update
    }
    
    let isLoading: Bool
    let text: NSAttributedString?
    let action:(()->Void)?
    private let update: UInt32?
    init(isLoading: Bool, text: NSAttributedString?, action:(()->Void)? = nil, update: UInt32? = nil) {
        self.isLoading = isLoading
        self.text = text
        self.action = action
        self.update = update
    }
}

final class InputDataGeneralTextData : Equatable {
    let color: NSColor
    let detectBold: Bool
    let viewType: GeneralViewType
    let rightItem: InputDataGeneralTextRightData
    let fontSize: CGFloat?
    let contextMenu:(()->[ContextMenuItem])?
    let clickable: Bool
    let inset: NSEdgeInsets
    let centerViewAlignment: Bool
    let alignment: NSTextAlignment
    let linkColor: NSColor
    init(color: NSColor = theme.colors.listGrayText, detectBold: Bool = true, viewType: GeneralViewType = .legacy, rightItem: InputDataGeneralTextRightData = InputDataGeneralTextRightData(isLoading: false, text: nil), fontSize: CGFloat? = nil, contextMenu:(()->[ContextMenuItem])? = nil, clickable: Bool = false, inset: NSEdgeInsets = .init(left: 20, right: 20, top:4, bottom:2), centerViewAlignment: Bool = false, alignment: NSTextAlignment = .left, linkColor: NSColor = theme.colors.link) {
        self.color = color
        self.detectBold = detectBold
        self.viewType = viewType
        self.rightItem = rightItem
        self.inset = inset
        self.fontSize = fontSize
        self.contextMenu = contextMenu
        self.clickable = clickable
        self.alignment = alignment
        self.centerViewAlignment = centerViewAlignment
        self.linkColor = linkColor
    }
    static func ==(lhs: InputDataGeneralTextData, rhs: InputDataGeneralTextData) -> Bool {
        return lhs.color == rhs.color && lhs.detectBold == rhs.detectBold && lhs.viewType == rhs.viewType && lhs.rightItem == rhs.rightItem && lhs.fontSize == rhs.fontSize && lhs.clickable == rhs.clickable && lhs.inset == rhs.inset && lhs.centerViewAlignment == rhs.centerViewAlignment && lhs.alignment == rhs.alignment && lhs.linkColor == rhs.linkColor
    }
}

final class InputDataRowData : Equatable {
    let viewType: GeneralViewType
    let rightItem: InputDataRightItem?
    let defaultText: String?
    let pasteFilter:((String)->(Bool, String))?
    let maxBlockWidth: CGFloat?
    let canMakeTransformations: Bool
    let customTheme: GeneralRowItem.Theme?
    init(viewType: GeneralViewType = .legacy, rightItem: InputDataRightItem? = nil, defaultText: String? = nil, maxBlockWidth: CGFloat? = nil, canMakeTransformations: Bool = false, pasteFilter:((String)->(Bool, String))? = nil, customTheme: GeneralRowItem.Theme? = nil) {
        self.viewType = viewType
        self.rightItem = rightItem
        self.defaultText = defaultText
        self.pasteFilter = pasteFilter
        self.maxBlockWidth = maxBlockWidth
        self.canMakeTransformations = canMakeTransformations
        self.customTheme = customTheme
    }
    static func ==(lhs: InputDataRowData, rhs: InputDataRowData) -> Bool {
        return lhs.viewType == rhs.viewType && lhs.rightItem == rhs.rightItem && lhs.defaultText == rhs.defaultText && lhs.maxBlockWidth == rhs.maxBlockWidth && lhs.canMakeTransformations == rhs.canMakeTransformations && lhs.customTheme == rhs.customTheme
    }
}

enum InputDataSectionType : Equatable {
    case normal
    case legacy
    case custom(CGFloat)
    case customModern(CGFloat)
    var height: CGFloat {
        switch self {
        case .normal:
            return 20
        case .legacy:
            return 20
        case let .custom(height):
            return height
        case let .customModern(height):
            return height
        }
    }
}

enum InputDataEntry : Identifiable, Comparable {
    case desc(sectionId: Int32, index: Int32, text: GeneralRowTextType, data: InputDataGeneralTextData)
    case input(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, mode: InputDataInputMode, data: InputDataRowData, placeholder: InputDataInputPlaceholder?, inputPlaceholder: String, filter:(String)->String, limit: Int32)
    case general(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, data: InputDataGeneralData)
    case dateSelector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String)
    case selector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String, viewType: GeneralViewType, values:[ValuesSelectorValue<InputDataValue>])
    case dataSelector(sectionId: Int32, index: Int32, value: InputDataValue, error: InputDataValueError?, identifier: InputDataIdentifier, placeholder: String, description: String?, icon: CGImage?, action:()->Void)
    case custom(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, equatable: InputDataEquatable?, comparable: InputDataComparableIndex?, item:(NSSize, InputDataEntryId)->TableRowItem)
    case search(sectionId: Int32, index: Int32, value: InputDataValue, identifier: InputDataIdentifier, update:(SearchState)->Void)
    case loading
    case sectionId(Int32, type: InputDataSectionType)
    
    var comparable: InputDataComparableIndex? {
        switch self {
        case let .custom(_, _, _, _, _, comparable, _):
            return comparable
        default:
            return nil
        }
    }
    
    var stableId: InputDataEntryId {
        switch self {
        case let .desc(_, index, _, _):
            return .desc(index)
        case let .input(_, _, _, _, identifier, _, _, _, _, _, _):
            return .input(identifier)
        case let .general(_, _, _, _, identifier, _):
            return .general(identifier)
        case let .selector(_, _, _, _, identifier, _, _, _):
            return .selector(identifier)
        case let .dataSelector(_, _, _, _, identifier, _, _, _, _):
            return .dataSelector(identifier)
        case let .dateSelector(_, _, _, _, identifier, _):
            return .dateSelector(identifier)
        case let .custom(_, _, _, identifier, _, _, _):
            return .custom(identifier)
        case let .search(_, _, _, identifier, _):
            return .custom(identifier)
        case let .sectionId(index, _):
            return .sectionId(index)
        case .loading:
            return .loading
        }
    }
    
    var stableIndex: Int32 {
        switch self {
        case let .desc(_, index, _, _):
            return index
        case let .input(_, index, _, _, _, _, _, _, _, _, _):
            return index
        case let .general(_, index, _, _, _, _):
            return index
        case let .selector(_, index, _, _, _, _, _, _):
            return index
        case let .dateSelector(_, index, _, _, _, _):
            return index
        case let .dataSelector(_, index, _, _, _, _, _, _, _):
            return index
        case let .custom(_, index, _, _, _, _, _):
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
        case let .desc(index, _, _, _):
            return index
        case let .input(index, _, _, _, _, _, _, _, _, _, _):
            return index
        case let .selector(index, _, _, _, _, _, _, _):
            return index
        case let .general(index, _, _, _, _, _):
            return index
        case let .dateSelector(index, _, _, _, _, _):
            return index
        case let .dataSelector(index, _, _, _, _, _, _, _, _):
            return index
        case let .custom(index, _, _, _, _, _, _):
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
        case let .sectionId(sectionId, _):
            return (sectionId + 1) * 100000 - sectionId
        default:
            return (sectionIndex * 100000) + stableIndex
        }
    }
    
    func item(arguments: InputDataArguments, initialSize: NSSize) -> TableRowItem {
        switch self {
        case let .sectionId(_, type):
            let viewType: GeneralViewType
            switch type {
            case .legacy, .custom:
                viewType = .legacy
            default:
                viewType = .separator
            }
            return GeneralRowItem(initialSize, height: type.height, stableId: stableId, viewType: viewType)
        case let .desc(_, _, text, data):
            return GeneralTextRowItem(initialSize, stableId: stableId, text: text, detectBold: data.detectBold, textColor: data.color, linkColor: data.linkColor, alignment: data.alignment, inset: data.inset, centerViewAlignment: data.centerViewAlignment, viewType: data.viewType, rightItem: data.rightItem, fontSize: data.fontSize, contextMenu: data.contextMenu, clickable: data.clickable)
        case let .custom(_, _, _, _, _, _, item):
            return item(initialSize, stableId)
        case let .selector(_, _, value, error, _, placeholder, viewType, values):
            return InputDataDataSelectorRowItem(initialSize, stableId: stableId, value: value, error: error, placeholder: placeholder, viewType: viewType, updated: arguments.dataUpdated, values: values)
        case let .dataSelector(_, _, _, error, _, placeholder, description, icon, action):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: placeholder, icon: icon, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: theme.colors.accent), description: description, type: .none, action: action, error: error)
        case let .general(_, _, value, error, identifier, data):
            return GeneralInteractedRowItem(initialSize, stableId: stableId, name: data.name, nameAttributed: data.nameAttributed, icon: data.icon, nameStyle: ControlStyle(font: .normal(.title), foregroundColor: data.color), description: data.description, descTextColor: data.descTextColor ?? data.theme?.grayTextColor ?? theme.colors.text, type: data.type, viewType: data.viewType, action: {
                data.action != nil ? data.action?() : arguments.select((identifier, value))
            }, enabled: data.enabled, switchAppearance: data.theme?.switchAppearance ?? switchViewAppearance, error: error, disabledAction: data.disabledAction ?? {}, menuItems: data.menuItems, customTheme: data.theme, disableBorder: data.disableBorder, switchAction: data.switchAction, descClick: data.descClick, afterNameImage: data.afterNameImage)
        case let .dateSelector(_, _, value, error, _, placeholder):
            return InputDataDateRowItem(initialSize, stableId: stableId, value: value, error: error, updated: arguments.dataUpdated, placeholder: placeholder)
        case let .input(_, _, value, error, _, mode, data, placeholder, inputPlaceholder, filter, limit: limit):
            return InputDataRowItem(initialSize, stableId: stableId, mode: mode, error: error, viewType: data.viewType, currentText: value.stringValue ?? "", currentAttributedText: value.attributedString, placeholder: placeholder, inputPlaceholder: inputPlaceholder, defaultText: data.defaultText, rightItem: data.rightItem, canMakeTransformations: data.canMakeTransformations, maxBlockWidth: data.maxBlockWidth, filter: filter, updated: { _ in
                arguments.dataUpdated()
            }, pasteFilter: data.pasteFilter, limit: limit, customTheme: data.customTheme)
        case .loading:
            return SearchEmptyRowItem(initialSize, stableId: stableId, isLoading: true)
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
    if let lhsComparable = lhs.comparable, let rhsComparable = rhs.comparable {
        return lhsComparable < rhsComparable
    }
    return lhs.index < rhs.index
}

func ==(lhs: InputDataEntry, rhs: InputDataEntry) -> Bool {
    switch lhs {
    case let .desc(sectionId, index, text, data):
        if case .desc(sectionId, index, text, data) = rhs {
            return true
        } else {
            return false
        }
    case let .input(sectionId, index, lhsValue, lhsError, identifier, mode, data, placeholder, inputPlaceholder, _, limit):
        if case .input(sectionId, index, let rhsValue, let rhsError, identifier, mode, data, placeholder, inputPlaceholder, _, limit) = rhs {
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
    case let .selector(sectionId, index, lhsValue, lhsError, identifier, placeholder, viewType, lhsValues):
        if case .selector(sectionId, index, let rhsValue, let rhsError, identifier, placeholder, viewType, let rhsValues) = rhs {
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
    case let .custom(_, _, value, identifier, lhsEquatable, comparable, _):
        if case .custom(_, _, value, identifier, let rhsEquatable, comparable, _) = rhs {
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
    case let .sectionId(id, type):
        if case .sectionId(id, type) = rhs {
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

class InputDataIdentifier : Hashable {
    let identifier: String
    init(_ identifier: String) {
        self.identifier = identifier
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(identifier)
    }
    func isEqual(to: InputDataIdentifier) -> Bool {
        if self.identifier == to.identifier {
            return true
        } else {
            return false
        }
    }
}

func ==(lhs: InputDataIdentifier, rhs: InputDataIdentifier) -> Bool {
    return lhs.isEqual(to: rhs)
}

enum InputDataValue : Equatable {
    case string(String?)
    case attributedString(NSAttributedString?)
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
    
    var attributedString:NSAttributedString? {
        switch self {
        case let .attributedString(value):
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
    case let .attributedString(lhsValue):
        if case let .attributedString(rhsValue) = rhs {
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
    case shakeWithData(Any)
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
