//
//  GridTableView.swift
//  TGUIKit
//
//  Created by keepcoder on 13/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class GridTableView: TableView {
    
    private let gridSize:NSSize

    public init(frame:NSRect, gridSize:NSSize) {
        self.gridSize = gridSize
        super.init(frame: frame, isFlipped: true)
    }
    
    public func apply(transition grid: GridTransition) {
        
        let transition = grid
        
        var row = GridRowItem(grid:self)
        var items:[GridRowItem] = []
        
        for (_, item, _) in transition.inserted {
            row.add(item: item)
            
            if row.isFilled {
                row.sizeToFit()
                items.append(row)
                row = GridRowItem(grid:self)
            }
        }
        
        if !row.isFilled && row.itemsCount > 0 {
            items.append(row)
            row.sizeToFit()
        }
        
        insert(items: items)
    }

    public func rowSetting() -> (Int,CGFloat) {
        let count:Int = Int(floor(frame.width/gridSize.width))
        let fitWidth:CGFloat = ceil(frame.width/CGFloat(count))
        return (count,fitWidth)
    }
    
    public override func contentInteractionView(for stableId: Int64) -> NSView? {
        
        for i in 0 ..< count - 1 {
            let row = self.item(at: i)
            
            if let row = row as? GridRowItem {
                let index = row.index(where:stableId)
                if let index = index {
                    let view = viewNecessary(at:i)
                    if let view = view, !NSIsEmptyRect(view.visibleRect) {
                        return view.subviews[index]
                    }
                }
                
            }
        }
        
        return nil
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
