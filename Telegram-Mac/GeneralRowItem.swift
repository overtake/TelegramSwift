//
//  GeneralRowItem.swift
//  Telegram-Mac
//
//  Created by keepcoder on 12/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit



enum GeneralInteractedType {
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
    
    
    init(_ initialSize: NSSize, height:CGFloat = 40.0, stableId:AnyHashable = arc4random(),type:GeneralInteractedType = .none, action:@escaping()->Void = {}, drawCustomSeparator:Bool = true, border:BorderType = [], inset:NSEdgeInsets = NSEdgeInsets(left: 30.0, right: 30.0), enabled: Bool = true) {
        self.type = type
        _height = height
        _stableId = stableId
        self.border = border
        self.inset = inset
        self.drawCustomSeparator = drawCustomSeparator
        self.action = action
        self.enabled = enabled
        super.init(initialSize)
        
        let _ = self.makeSize(initialSize.width)
    }
    override var instantlyResize: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return GeneralRowView.self
    }
    
}
