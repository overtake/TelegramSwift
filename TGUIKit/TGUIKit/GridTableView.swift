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
    
    public func refill(_ items:[TableRowItem]) -> Void {
        
        for i in 0 ..< items.count {
            let row = items[i] as! GridRowItem
            let compressed = row.compress()
            
            if items.count - 1 > i {
                let next = items[i + 1] as! GridRowItem
                var fill:Int = row.count - row.itemsCount
                
                for j in 0 ..< fill {
                    row.add(item: next.items[0])
                    next.remove(at: 0)
                }
               
            }
            
        }
        
    }
    
    public func apply(transition grid: GridTransition) {
        
        let transition = grid
        
//        if transition.deleted.count == 0 && transition.inserted.count == 0 {
//            return
//        }
        
        self.beginUpdates()
        
        
        var rd:Int = 0
        
        var stream:[GridItem] = []
        
        for i in 0 ..< self.count {
            let item = self.item(at: i) as! GridRowItem
            for grid in item.items {
                if !grid.isKind(of: EmptyGridItem.self) {
                    stream.append(grid)
                }
            }
        }
        
        
        for rdx in transition.deleted {
            var s:Bool = false
            for (_,_,prev) in transition.inserted {
                if let p = prev {
                    s = rdx == p
                }
                if(s) {
                    break
                }
            }
            if(!s) {
                stream.remove(at: rdx - rd)
                rd+=1
            }
        }
        
        
        for (idx,item,prev) in transition.inserted {
            if let prev = prev {
                stream.remove(at: prev)
                stream.insert(item, at: idx)
            } else {
                stream.insert(item, at: idx)
                
            }
        }
        
        var copy:[TableRowItem] = []

        var row = GridRowItem(grid:self)
        
        var scount:Int = copy.count * row.count
        
        var i:Int = 0
        for item in stream {
            row.add(item: item)
            if row.isFilled {
                row.sizeToFit()
                copy.append(row)
                row = GridRowItem(grid:self)
            }
           
            i += 1
        }
        
        if !row.isFilled && row.itemsCount > 0 {
            copy.append(row)
            row.sizeToFit()
        }
        
        var from:[Int64:(NSRect,NSView)]!
        if transition.animated {
            from = rects(true)
        }

        tableView.beginUpdates()
        
        var reload:Bool = false
        
        var j:Int = 0
        for item in copy {
            if let s = self.item(stableId: item.stableId) {
                if index(of: s) == j {
                    self.reloadData(row: j)
                } else {
                    reload = true
                }
            } else {
                if j != copy.count - 1 {
                    reload = true
                }
                
            }
            
            if reload {
                break
            }
            
            j+=1
        }
        if reload {
            self.removeAll(redraw: true)
            self.insert(items: copy, redraw:true)
        }
      
        
        tableView.endUpdates()
        
        if transition.animated {
            var to:[Int64:(NSRect,NSView)] = from.count > 0 ? rects(false) : [:]
            animate(from:from, to:to)
        }
        
        endUpdates()
    }
    
    func animate(from:[Int64:(NSRect,NSView)] , to:[Int64:(NSRect,NSView)] ) -> Void {
        
        for (key,toRect) in to {
            if let fromRect = from[key] {
                
                self.addSubview(fromRect.1)
                fromRect.1.frame = toRect.0
                toRect.1.isHidden = true
                
                fromRect.1.layer?.animatePosition(from: fromRect.0.origin, to: toRect.0.origin, duration: 0.25, timingFunction: kCAMediaTimingFunctionSpring, removeOnCompletion:false, completion: { (complete) in
                    toRect.1.isHidden = false
                    fromRect.1.removeFromSuperview()
                })
            }
        }
 
    }
    
    func rects(_ copyView:Bool) -> [Int64:(NSRect,NSView)] {
        var result:[Int64:(NSRect,NSView)] = [:]
        let visible = visibleRows()
        for i in visible.location ..< visible.location + visible.length {
            let view = viewNecessary(at:i)
            let item = self.item(at: i) as! GridRowItem
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                for j in 0 ..< item.items.count {
                    let subview = (copyView ? view.subviews[j].copy() : view.subviews[j]) as! GridView
                    
                    let rect = view.convert(subview.frame, to: self)
                    if copyView {
                        subview.item = item.items[j]
                        subview.frame = rect
                    }
                    result[item.items[j].stableId] = (rect,subview)
                }
              
            }
        }
        return result
    }
    
    
    /*
     for rdx in transition.deleted {
     
     var s:Bool = false
     
     for (_,_,prev) in transition.inserted {
     
     if let p = prev {
     s = rdx == p
     }
     
     if(s) {
     break
     }
     }
     if(!s) {
     let idx = rdx - rd
     let index = self.row(for: idx)
     let item = self.item(at: index) as! GridRowItem
     let gridIndeex = idx % item.itemsCount
     item.remove(at: gridIndeex)
     
     rd+=1
     }
     }
     
     
     refill()
     
     
     var row = GridRowItem(grid:self)
     var items:[GridRowItem] = []
     
     for (to, item, prev) in transition.inserted {
     
     let rowIndex = to / count
     
     if let prev = prev {
     
     
     
     } else {
     row.add(item: item)
     }
     
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
 */
    
    public func row(for index:Int) -> Int {
        let (count,_) = rowSetting()
        
        return index / count
    }
    

    public func rowSetting() -> (Int,CGFloat) {
        let count:Int = Int(floor(frame.width/gridSize.width))
        let fitWidth:CGFloat = ceil(frame.width/CGFloat(count))
        return (count,fitWidth)
    }
    
    override public func contentInteractionView(for stableId: Int64) -> NSView? {
        
        for i in 0 ..< count {
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
    
    public override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        apply(transition: GridTransition(deleted: [], inserted: []))
//        var visible = visibleRows()
//        for i in visible.location ..< visible.location + visible.length {
//            let item = self.item(at: i) as! GridRowItem
//            item.sizeToFit()
//            self.reloadData(row: i)
//        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
