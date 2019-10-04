//
//  DynamicHeightRowItem.swift
//  Telegram
//
//  Created by Mikhail Filimonov on 03/10/2019.
//  Copyright © 2019 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit


enum DynamicItemSide {
    case top
    case bottom
}
class DynamicHeightRowItem: GeneralRowItem {
    private let side:DynamicItemSide
    init(_ initialSize: NSSize, stableId: AnyHashable, side: DynamicItemSide) {
        self.side = side
        super.init(initialSize, stableId: stableId)
    }
    
    override var height: CGFloat {
        if let table = table {
            var tableHeight: CGFloat = 0
            table.enumerateItems { item -> Bool in
                if !item.reloadOnTableHeightChanged {
                    tableHeight += item.height
                }
                return true
            }
            
            return max((table.frame.height - tableHeight) / 2, 0)
        } else {
            return 0
        }
    }
    
    override var instantlyResize: Bool {
        return true
    }
    override var reloadOnTableHeightChanged: Bool {
        return true
    }
    
    override func viewClass() -> AnyClass {
        return DynamicHeightRowView.self
    }
}

private final class DynamicHeightRowView : TableRowView {
    override func updateColors() {
        
    }
    
    override var firstResponder: NSResponder? {
        return nil
    }
}
