//
//  TableStickItem.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableStickItem: TableRowItem {

    let _stableId = Int64(arc4random())
    open override var stableId: AnyHashable {
        return _stableId
    }
    
    
    open var headerHeight: CGFloat {
        return height
    }
    
    open override var height: CGFloat {
        return 30.0
    }
    
    public required override init(_ initialSize:NSSize) {
        super.init(initialSize)
    }
    
    open override func viewClass() -> AnyClass {
        return TableStickView.self
    }
    
    
    
}
