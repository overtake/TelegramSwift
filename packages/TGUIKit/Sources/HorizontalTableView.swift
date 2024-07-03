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
    
    public override func updateAfterInitialize(isFlipped: Bool = true, bottomInset: CGFloat = 0, drawBorder: Bool = false) {
        super.updateAfterInitialize(isFlipped: isFlipped, bottomInset: bottomInset, drawBorder: drawBorder)
        
        self.hasHorizontalScroller = false
        self.horizontalScrollElasticity = .none
    }
    
    
    
    override open func scrollWheel(with event: NSEvent) {
        
        if let applyExternalScroll = self.applyExternalScroll, applyExternalScroll(event) {
            return
        }
        
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.y += -event.scrollingDeltaY
            } else {
                scrollPoint.y -= event.scrollingDeltaY
            }
            scrollPoint.y = max(0, min(scrollPoint.y, listHeight - clipView.bounds.height))
            clipView.scroll(to: scrollPoint)
            window?.scrollWheel(with: event)
            return
        }
        if event.scrollingDeltaY != 0 || event.scrollingDeltaX != 0 {
            super.scrollWheel(with: event)
        }

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


open class HorizontalScrollView : ScrollView {
    
    
    
    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.hasVerticalScroller = false
        self.verticalScrollElasticity = .none
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override open func scrollWheel(with event: NSEvent) {
        
        if let applyExternalScroll = self.applyExternalScroll, applyExternalScroll(event) {
            return
        }
        
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
            scrollPoint.x = min(max(0, floorToScreenPixels(backingScaleFactor, scrollPoint.x)), documentView!.frame.width - frame.width)
            clipView.scroll(to: scrollPoint)
            window?.scrollWheel(with: event)
            return
        }
       
        if documentView!.frame.width > frame.width {
            if event.scrollingDeltaY != 0 || event.scrollingDeltaX != 0 {
                super.scrollWheel(with: event)
            }
        } else {
            superview?.scrollWheel(with: event)
        }
    }
    
    public func makeScrollPoint(_ event: NSEvent) -> NSPoint {
        var scrollPoint = contentView.bounds.origin
        let isInverted: Bool = System.isScrollInverted
        if event.scrollingDeltaY != 0 {
            if isInverted {
                scrollPoint.x += -event.scrollingDeltaY
            } else {
                scrollPoint.x -= event.scrollingDeltaY
            }
        }
        if event.scrollingDeltaX != 0 {
            if !isInverted {
                scrollPoint.x += -event.scrollingDeltaX
            } else {
                scrollPoint.x -= event.scrollingDeltaX
            }
        }
        return scrollPoint
    }
}
