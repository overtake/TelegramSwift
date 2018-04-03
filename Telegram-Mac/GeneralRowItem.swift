//
//  GeneralRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



enum GeneralInteractedType : Equatable {
    case none
    case next
    case selectable(stateback:()->Bool)
    case switchable(stateback:()->Bool)
    case context(stateback:()->String)
    case image(stateback:()->CGImage)
    case button(stateback:()->String)
    case search(stateback:(String)->Bool)
    case colorSelector(stateback:()->NSColor)
}

func ==(lhs: GeneralInteractedType, rhs: GeneralInteractedType) -> Bool {
    switch lhs {
    case .none:
        if case .none = rhs {
            return true
        } else {
            return false
        }
    case .next:
        if case .next = rhs {
            return true
        } else {
            return false
        }
    case let .selectable(lhsStateback):
        if case let .selectable(rhsStateback) = rhs {
            return lhsStateback() == rhsStateback()
        } else {
            return false
        }
    case let .switchable(lhsStateback):
        if case let .switchable(rhsStateback) = rhs {
            return lhsStateback() == rhsStateback()
        } else {
            return false
        }
    case let .context(lhsStateback):
        if case let .context(rhsStateback) = rhs {
            return lhsStateback() == rhsStateback()
        } else {
            return false
        }
    case let .image(lhsStateback):
        if case let .image(rhsStateback) = rhs {
            return lhsStateback() === rhsStateback()
        } else {
            return false
        }
    case let .button(lhsStateback):
        if case let .button(rhsStateback) = rhs {
            return lhsStateback() == rhsStateback()
        } else {
            return false
        }
    case .search:
        if case .search = rhs {
            return true
        } else {
            return false
        }
    case let .colorSelector(lhsStateback):
        if case let .colorSelector(rhsStateback) = rhs {
            return lhsStateback() == rhsStateback()
        } else {
            return false
        }
    }
}

class GeneralRowItem: TableRowItem {

    let border:BorderType
    let enabled: Bool
    let _height:CGFloat
    override var height: CGFloat {
        return _height
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
    
    let inset:NSEdgeInsets
    
    private(set) var action:()->Void
    private(set) var type:GeneralInteractedType
    
    let backgroundColor: NSColor
    
    init(_ initialSize: NSSize, height:CGFloat = 40.0, stableId:AnyHashable = arc4random(),type:GeneralInteractedType = .none, action:@escaping()->Void = {}, drawCustomSeparator:Bool = true, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), enabled: Bool = true, backgroundColor: NSColor = .clear) {
        self.type = type
        _height = height
        _stableId = stableId
        self.border = border
        self.inset = inset
        self.backgroundColor = backgroundColor
        self.drawCustomSeparator = drawCustomSeparator
        self.action = action
        self.enabled = enabled
        super.init(initialSize)
        
        let _ = self.makeSize(initialSize.width)
    }
    override var instantlyResize: Bool {
        return true
    }
    
    override var isUniqueView: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GeneralRowView.self
    }
    
}
