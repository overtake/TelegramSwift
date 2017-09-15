//
//  TableStickView.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableStickView: TableRowView {

    open var header:Bool = false {
        didSet {
            if header != oldValue {
                needsDisplay = true
            }
        }
    }
    
    open func updateIsVisible(_ visible: Bool, animated: Bool) {
        
    }
    
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
    }
    
}
