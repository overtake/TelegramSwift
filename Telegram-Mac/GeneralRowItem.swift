//
//  GeneralRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit

enum InputDataValueErrorTarget : Equatable {
    case data
    case files
}

struct InputDataValueError : Equatable {
    let description: String
    let target: InputDataValueErrorTarget
    init(description: String, target: InputDataValueErrorTarget) {
        self.description = description
        self.target = target
    }
}

func bestGeneralViewType<T>(_ array:[T], for item: T) -> GeneralViewType where T: AnyObject {
    for _ in array {
        if item === array.first && item === array.last {
            return .singleItem
        } else if item === array.first {
            return .firstItem
        } else if item === array.last {
            return .lastItem
        } else {
            return .innerItem
        }
    }
    return .singleItem
}

func bestGeneralViewType<T>(_ array:[T], for item: T) -> GeneralViewType where T: Equatable {
    for _ in array {
        if item == array.first && item == array.last {
            return .singleItem
        } else if item == array.first {
            return .firstItem
        } else if item == array.last {
            return .lastItem
        } else {
            return .innerItem
        }
    }
    return .singleItem
}

func bestGeneralViewType<T>(_ array:[T], for i: Int) -> GeneralViewType  {
    if array.count <= 1 {
        return .singleItem
    } else if i == 0 {
        return .firstItem
    } else if i == array.count - 1 {
        return .lastItem
    } else {
        return .innerItem
    }
}

enum GeneralInteractedType : Equatable {
    case none
    case next
    case nextContext(String)
    case selectable(Bool)
    case switchable(Bool)
    case context(String)
    case loading
    case image(CGImage)
    case button(String)
    case search(Bool)
    case colorSelector(NSColor)
    #if !SHARE
    case contextSelector(String, [SPopoverItem])
    #endif
}


final class GeneralViewItemCorners : OptionSet {
    public var rawValue: Int32
    
    public init() {
        self.rawValue = 0
    }
    
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }
    
    public static let topLeft = GeneralViewItemCorners(rawValue: (1 << 0))
    public static let topRight = GeneralViewItemCorners(rawValue: (1 << 1))
    public static let bottomLeft = GeneralViewItemCorners(rawValue: (1 << 2))
    public static let bottomRight = GeneralViewItemCorners(rawValue: (1 << 3))
    
    static var all: GeneralViewItemCorners {
        return [.topLeft, .topRight, .bottomLeft, .bottomRight]
    }

}

enum GeneralViewItemPosition : Equatable {
    case first
    case last
    case inner
    case single
    var corners: GeneralViewItemCorners {
        switch self {
        case .first:
            return [.topLeft, .topRight]
        case .inner:
            return []
        case .last:
            return [.bottomLeft, .bottomRight]
        case .single:
            return [.topLeft, .topRight, .bottomRight, .bottomLeft]
        }
    }
    
    
    
    var border: Bool {
        guard theme.colors.listBackground != theme.colors.background else {
            return true
        }
        switch self {
        case .first, .inner:
            return true
        default:
            return false
        }
    }
    
}

extension NSEdgeInsets : Equatable {
    public static func ==(lhs: NSEdgeInsets, rhs: NSEdgeInsets) -> Bool {
        return lhs.left == rhs.left && lhs.top == rhs.top && lhs.right == rhs.right && lhs.bottom == rhs.bottom
    }
}

enum GeneralViewType : Equatable {
    case legacy
    case modern(position: GeneralViewItemPosition, insets: NSEdgeInsets)

    var isPlainMode: Bool {
        return theme.colors.listBackground == theme.colors.background || self == .legacy
    }
    var innerInset: NSEdgeInsets {
        switch self {
        case .legacy:
            return NSEdgeInsetsMake(0, 0, 0, 0)
        case let .modern(_, insets):
            return insets
        }
    }
    
    var rowBackground: NSColor {
        switch self {
        case .legacy:
            return theme.colors.background
        case .modern:
            return .clear
        }
    }
    
    var corners:GeneralViewItemCorners {
        switch self {
        case .legacy:
            return []
        case let .modern(position, _):
            return isPlainMode ? [] : position.corners
        }
    }
    var hasBorder: Bool {
        switch self {
        case .legacy:
            return false
        case let .modern(position, _):
            return position.border
        }
    }
    var position: GeneralViewItemPosition {
        switch self {
        case .legacy:
            return .single
        case let .modern(position, _):
            return position
        }
    }
    
    static var firstItem: GeneralViewType {
        return .modern(position: .first, insets: NSEdgeInsetsMake(12, 16, 12, 16))
    }
    static var innerItem: GeneralViewType {
        return .modern(position: .inner, insets: NSEdgeInsetsMake(12, 16, 12, 16))
    }
    static var lastItem: GeneralViewType {
        return .modern(position: .last, insets: NSEdgeInsetsMake(12, 16, 12, 16))
    }
    static var singleItem: GeneralViewType {
        return .modern(position: .single, insets: NSEdgeInsetsMake(12, 16, 12, 16))
    }
    static var textTopItem: GeneralViewType {
        return .modern(position: .single, insets: NSEdgeInsetsMake(0, 16, 5, 0))
    }
    static var textBottomItem: GeneralViewType {
        return .modern(position: .single, insets: NSEdgeInsetsMake(5, 16, 0, 0))
    }
    static var separator: GeneralViewType {
        return .modern(position: .single, insets: NSEdgeInsetsMake(0, 0, 0, 0))
    }
    static func plain(_ position: GeneralViewItemPosition) -> GeneralViewType {
        return .modern(position: position, insets: NSEdgeInsetsMake(0, 0, 0, 0))
    }
}

class GeneralRowItem: TableRowItem {

    let border:BorderType
    let enabled: Bool
    let _height:CGFloat
    override var height: CGFloat {
        var height = _height
        if let errorLayout = errorLayout {
            height += errorLayout.layoutSize.height
        }
        return height
    }
    
    private let _stableId:AnyHashable
    override var stableId: AnyHashable {
        return _stableId
    }
        
    var drawCustomSeparator:Bool = true {
        didSet {
            if drawCustomSeparator != oldValue {
                self.redraw()
            }
        }
    }
    
    private let _inset: NSEdgeInsets
    var inset:NSEdgeInsets {
        return _inset
    }
    
    
    private(set) var action:()->Void
    var type:GeneralInteractedType
    
    let backgroundColor: NSColor
    
    let error: InputDataValueError?
    let errorLayout: TextViewLayout?
    
    
    private(set) var viewType: GeneralViewType

    
    func updateViewType(_ viewType: GeneralViewType) {
        self.viewType = viewType
    }
    
    init(_ initialSize: NSSize, height:CGFloat = 40.0, stableId:AnyHashable = arc4random(),type:GeneralInteractedType = .none, viewType: GeneralViewType = .legacy, action:@escaping()->Void = {}, drawCustomSeparator:Bool = true, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), enabled: Bool = true, backgroundColor: NSColor? = nil, error: InputDataValueError? = nil) {
        self.type = type
        _height = height
        _stableId = stableId
        self.border = border
        self._inset = inset
        
        if let backgroundColor = backgroundColor {
            self.backgroundColor = backgroundColor
        } else {
            self.backgroundColor = viewType.rowBackground
        }
        
        self.drawCustomSeparator = drawCustomSeparator
        self.action = action
        self.enabled = enabled
        self.error = error
        self.viewType = viewType
        if let error = error {
            errorLayout = TextViewLayout(.initialize(string: error.description, color: theme.colors.redUI, font: .normal(.text)))
        } else {
            errorLayout = nil
        }
        
        super.init(initialSize)
        
        let _ = self.makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        let success = super.makeSize(width, oldWidth: oldWidth)
        errorLayout?.measure(width: width - inset.left - inset.right)
        return success
    }
    
    override var instantlyResize: Bool {
        return true
    }
    
    override var canBeAnchor: Bool {
        return false
    }
    
    override var isUniqueView: Bool {
        return true
    }
    
    var blockWidth: CGFloat {
        switch self.viewType {
        case .legacy:
            return self.width - self.inset.left - self.inset.right
        case .modern:
            return min(600, self.width - self.inset.left - self.inset.right)
        }
    }
    
    override func viewClass() -> AnyClass {
        return GeneralRowView.self
    }
    
}
