//
//  TableStickView.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableStickView: TableRowView {

    public var header:Bool = false {
        didSet {
            if header != oldValue {
                needsDisplay = true
            }
        }
    }
    
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
}
