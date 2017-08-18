//
//  GridItem.swift
//  TGUIKit
//
//  Created by keepcoder on 16/08/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa

public protocol GridSection {
    var height: CGFloat { get }
    var hashValue: Int { get }
    
    func isEqual(to: GridSection) -> Bool
    func node() -> View
}

public protocol GridItem {
    var section: GridSection? { get }
    func node(layout: GridNodeLayout, gridNode: GridNode) -> GridItemNode
    func update(node: GridItemNode)
    var aspectRatio: CGFloat { get }
}

public extension GridItem {
    var aspectRatio: CGFloat {
        return 1.0
    }
}
