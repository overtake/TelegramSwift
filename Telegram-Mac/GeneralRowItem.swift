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
}

enum GeneralInteractedType : Equatable {
    case none
    case next
    case nextContext(String)
    case selectable(Bool)
    case switchable(Bool)
    case context(String)
    case image(CGImage)
    case button(String)
    case search(Bool)
    case colorSelector(NSColor)
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
    
    let inset:NSEdgeInsets
    
    private(set) var action:()->Void
    var type:GeneralInteractedType
    
    let backgroundColor: NSColor
    
    let error: InputDataValueError?
    let errorLayout: TextViewLayout?

    
    init(_ initialSize: NSSize, height:CGFloat = 40.0, stableId:AnyHashable = arc4random(),type:GeneralInteractedType = .none, action:@escaping()->Void = {}, drawCustomSeparator:Bool = true, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), enabled: Bool = true, backgroundColor: NSColor = .clear, error: InputDataValueError? = nil) {
        self.type = type
        _height = height
        _stableId = stableId
        self.border = border
        self.inset = inset
        self.backgroundColor = backgroundColor
        self.drawCustomSeparator = drawCustomSeparator
        self.action = action
        self.enabled = enabled
        self.error = error
        
        if let error = error {
            errorLayout = TextViewLayout(.initialize(string: error.description, color: theme.colors.redUI, font: .normal(.text)))
        } else {
            errorLayout = nil
        }
        
        super.init(initialSize)
        
        let _ = self.makeSize(initialSize.width)
    }
    
    override func makeSize(_ width: CGFloat, oldWidth: CGFloat = 0) -> Bool {
        errorLayout?.measure(width: width - inset.left - inset.right)
        return super.makeSize(width, oldWidth: oldWidth)
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
