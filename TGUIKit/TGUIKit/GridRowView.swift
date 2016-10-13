//
//  GridRowView.swift
//  TGUIKit
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class GridView : OverlayControl {
    
    public private(set) weak var item:GridItem?
    
    required public override init() {
        super.init()
        self.backgroundColor = TGColor.grayBackground
    }
    
    open func set(item:GridItem, animated:Bool = true) {
        self.item = item
    }
    
    override required public init(frame frameRect: NSRect) {
         fatalError("init(coder:) has not been implemented")
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

public class GridRowView: TableRowView {
    
    public override func set(item:TableRowItem, animated:Bool = false) {
        super.set(item: item, animated: animated)
        
        if let item = item as? GridRowItem {
            layout(items:item.items, parent: item, animated:animated)
        }
    }
    
    func layout(items:[GridItem], parent:GridRowItem, animated:Bool) {
        while subviews.count > items.count {
            subviews.removeLast()
        }
        var x:CGFloat = parent.inset
        var i:Int = 0
        for item in items {
            var view:GridView?
           
            if subviews.count > i {
                let v = subviews[i]
                if v.isKind(of: item.viewClass) {
                    view = v as? GridView
                } else {
                    v.removeFromSuperview()
                }
            }
            
            if view == nil {
                var vz = item.viewClass as! GridView.Type
                view = vz.init()
                addSubview(view!)
            }
            
            if let view = view {
                view.frame = NSMakeRect(x, parent.inset, item.size.width, item.size.height)

                if view.item != item {
                     view.set(item: item, animated: animated)
                }
                x += item.size.width + parent.inset
            }
            
            
            
            i += 1
        }

    }
    

    
}
