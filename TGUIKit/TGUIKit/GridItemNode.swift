//
//  GridItemNode.swift
//  TGUIKit
//
//  Created by keepcoder on 16/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa


open class GridItemNode: ImageButton {
    
    open var stableId:AnyHashable {
        return 0
    }
    
    public private(set) weak var grid:GridNode?
    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    public init(_ grid:GridNode) {
        super.init()
        self.grid = grid
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open var isVisibleInGrid = false
    open var isGridScrolling = false
    
}
