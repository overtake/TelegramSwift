//
//  HorizontalTableView.swift
//  TGUIKit
//
//  Created by keepcoder on 17/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class HorizontalTableView: TableView {

    public override init(frame frameRect: NSRect, isFlipped: Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {
        super.init(frame: frameRect, isFlipped: isFlipped, bottomInset: bottomInset, drawBorder: drawBorder)
        //        [[self.scrollView verticalScroller] setControlSize:NSSmallControlSize];
        //self.verticalScroller?.controlSize = NSControlSize.small
        self.rotate(byDegrees: 270)
        
        self.clipView.border = []
        self.tableView.border = []
    }
    
    public override func scrollWheel(with event: NSEvent) {
                
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        let scrollingDeltaY: CGFloat
        if event.scrollingDeltaY < 0 {
            scrollingDeltaY = min(-1, event.scrollingDeltaY)
        } else {
            scrollingDeltaY = max(1, event.scrollingDeltaY)
        }
        if scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.y += -scrollingDeltaY
            } else {
                scrollPoint.y -= scrollingDeltaY
            }
        }
        
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.y += -scrollingDeltaY
            } else {
                scrollPoint.y -= scrollingDeltaY
            }
        }
               
        scrollPoint.y = max(0, min(scrollPoint.y, listHeight - clipView.bounds.height))
        clipView.scroll(to: scrollPoint)


    }
    
    
    open override var hasVerticalScroller: Bool {
        get {
            return false
        }
        set {
            super.hasVerticalScroller = newValue
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func rowView(item:TableRowItem) -> TableRowView {
        let identifier:String = item.identifier
        
        if let resortView = self.resortController?.resortView {
            if resortView.item?.stableId == item.stableId {
                return resortView
            }
        }
        var view: NSView? = item.isUniqueView ? nil : self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: self.tableView)
        
        if(view == nil) {
            let vz = item.viewClass() as! TableRowView.Type
            
            view = vz.init(frame:NSMakeRect(0, 0, item.height, frame.height))
            
            view?.identifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
            
        }
        
        return view as! TableRowView;
    }
    
    public override func viewNecessary(at row:Int, makeIfNecessary: Bool = false) -> TableRowView? {
        if row < 0 || row >= count {
            return nil
        }
        if let resortView = self.resortController?.resortView {
            if resortView.item?.stableId == self.item(at: row).stableId {
                return resortView
            }
        }
        return self.tableView.rowView(atRow: row, makeIfNecessary: makeIfNecessary) as? TableRowView
    }
    
}
