//
//  TableView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

public enum TableSeparator {
    case bottom;
    case top;
    case right;
    case left;
    case none;
}

public final class TableTransition {
    public private(set) var inserted:[(Int,TableRowItem,Int?)]
    public private(set) var deleted:[Int]
    public private(set) var scrollState:TableScrollState
    public private(set) var animated:Bool
    
    public init(deleted:[Int], inserted:[(Int,TableRowItem,Int?)], animated:Bool = false, scrollState:TableScrollState = .none(nil)) {
        self.inserted = inserted
        self.deleted = deleted
        self.animated = animated
        self.scrollState = scrollState
    }
}

public protocol TableViewDelegate : class {
    
    func selectionDidChange(row:Int, item:TableRowItem) -> Void;
    func isSelectable(row:Int, item:TableRowItem) -> Bool;
    
}

public enum TableScrollState {
    case top(TableRowItem, TableAnimationInterface?); // stableId
    case bottom(TableRowItem, TableAnimationInterface?); // stableId
    case center(TableRowItem, TableAnimationInterface?); // stableId
    case save(TableAnimationInterface?);
    case none(TableAnimationInterface?);
}

protocol SelectDelegate : class {
    func selectRow(index:Int) -> Void;
}

private class TGFlipableTableView : NSTableView, CALayerDelegate {
    
    public var flip:Bool = true
    
    public weak var sdelegate:SelectDelegate?
    
    var border:BorderType?
    
    private override var isFlipped: Bool {
        return flip
    }
    
    public override func draw(_ dirtyRect: NSRect) {
       
    }

    
    private override func addSubview(_ view: NSView) {
        super.addSubview(view)
    }
    
    fileprivate func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(TGColor.white.cgColor)
        ctx.fill(self.bounds)
        
        if let border = border {
            
            ctx.setFillColor(TGColor.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, NSHeight(self.frame) - TGColor.borderSize, NSWidth(self.frame), TGColor.borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, NSWidth(self.frame), TGColor.borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, TGColor.borderSize, NSHeight(self.frame)))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(NSWidth(self.frame) - TGColor.borderSize, 0, TGColor.borderSize, NSHeight(self.frame)))
            }
            
        }
    }

    
    private override func mouseDown(with event: NSEvent) {
        
       
        let point = self.convert(event.locationInWindow, from: nil)
        
        let range  = self.rows(in: NSMakeRect(point.x, point.y, 1, 1));
        
        sdelegate?.selectRow(index: range.location)

        
    }
    
    private override func mouseUp(with event: NSEvent) {
        
    }

}

public protocol InteractionContentViewProtocol : class {
    func contentInteractionView(for stableId:Int64) -> NSView?
}

open class TableView: ScrollView, NSTableViewDelegate,NSTableViewDataSource,SelectDelegate,InteractionContentViewProtocol {
    
    public var separator:TableSeparator = .none
    
    private var list:[TableRowItem] = [TableRowItem]();
    private var tableView:TGFlipableTableView
    weak public var delegate:TableViewDelegate?
    private var trackingArea:NSTrackingArea?
    private var listhash:[Int64:TableRowItem] = [Int64:TableRowItem]();
    
    
    private var selectedhash:Atomic<Int64> = Atomic(value: -1);
   
    
    private var updating:Bool = false
    
    private var previousScroll:ScrollPosition?
    
    private var scrollHandler:(_ scrollPosition:ScrollPosition) ->Void = {_ in}
    
    public var count:Int {
        get {
            return self.list.count
        }
    }
    

    open override var isFlipped: Bool {
        return true
    }
    
    public init(frame frameRect: NSRect, isFlipped:Bool = true) {
        
        let table = TGFlipableTableView.init(frame:frameRect);
        table.flip = isFlipped
        
        

        self.tableView = table
        self.tableView.wantsLayer = true
        
        self.tableView.layer?.drawsAsynchronously = System.drawAsync
        self.tableView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        

        super.init(frame: frameRect);
        
        self.clipView.border = BorderType([.Right])
        self.tableView.border = BorderType([.Right])

        self.hasVerticalScroller = true;

        self.documentView = self.tableView;
        self.autoresizesSubviews = true;
        self.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewHeightSizable]
        
      //  table.frameRotation = -10
        
      //  self.frameCenterRotation = 0.5
        
       // self.layer?.sublayerTransform = CATransform3DMakeRotation(90 * CGFloat(M_PI) / 180, 0.0, 0.0, 1.0);

        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.sdelegate = self

        self.updateTrackingAreas();
        

        var column:NSTableColumn = NSTableColumn.init(identifier: "column");
        column.width = NSWidth(frameRect)
        self.tableView.addTableColumn(column)
        
        
        self.tableView.headerView = nil;
        
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        
    }
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
    }
    
    let reqCount = 4
    
    open override func viewDidMoveToSuperview() {
        if let sv = superview {
            let clipView = self.contentView
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NSViewBoundsDidChange, object: clipView, queue: nil, using: { [weak self] notification  in
                if let strongSelf = self {
                    if (strongSelf.scrollHandler != nil && !strongSelf.updating) {
                        
                        let scroll = strongSelf.scrollPosition
                    
                        
                        let range = strongSelf.tableView.rows(in: strongSelf.tableView.visibleRect)
                        
                        if(scroll.direction != strongSelf.previousScroll?.direction) {
                            
                            switch(scroll.direction) {
                            case .top:
                                if(range.location  <=  strongSelf.reqCount) {
                                    strongSelf.scrollHandler(scroll)
                                    strongSelf.previousScroll = scroll

                                }
                            case .bottom:
                                if(strongSelf.count - (range.location + range.length) <= strongSelf.reqCount) {
                                    strongSelf.scrollHandler(scroll)
                                    strongSelf.previousScroll = scroll

                                }
                            case .none:
                                strongSelf.scrollHandler(scroll)
                                strongSelf.previousScroll = scroll

                            }
                        }
 
                    }
                }
 
            })
        } else {
           NotificationCenter.default.removeObserver(self)
        }
    }
    
    public func resetScrollNotifies() ->Void {
        self.previousScroll = nil
    }

    
    open override func updateTrackingAreas() {
        super.updateTrackingAreas();
        
        if(self.trackingArea != nil) {
            self.removeTrackingArea(self.trackingArea!)
        }
        let options:NSTrackingAreaOptions = [NSTrackingAreaOptions.mouseEnteredAndExited, NSTrackingAreaOptions.inVisibleRect, NSTrackingAreaOptions.activeAlways, NSTrackingAreaOptions.mouseMoved]
        self.trackingArea = NSTrackingArea.init(rect: self.bounds, options: options, owner: self, userInfo: nil)
        
        self.addTrackingArea(self.trackingArea!)
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin);
        self.updateTrackingAreas();
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public func selectedItem() -> TableRowItem? {
        
        let hash = selectedhash.modify({$0})
        
        if(hash != -1) {
            return self.item(stableId:hash);
        }
        
        return nil;
    }
    
    public func isSelected(_ item:TableRowItem) ->Bool {
        return selectedhash.modify({$0}) == item.stableId
    }
    
    public func item(stableId:Int64) -> TableRowItem? {
        return self.listhash[stableId];
    }
    
    public func index(of:TableRowItem) -> Int? {
        
        if let it = self.listhash[of.stableId] {
            return self.list.index(of: it);
        }
        
        return nil
    }
    
    public func index(hash:Int64) -> Int? {
        
        if let it = self.listhash[hash] {
            return self.list.index(of: it);
        }
        
        return nil
    }
    
    public func insert(item:TableRowItem, at:Int, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Bool {
        
        if(self.item(stableId:item.stableId) == nil) {
            
            self.listhash[item.stableId] = item;
            self.list.insert(item, at: at);
            item.table = self;
            
            if(redraw) {
                self.tableView.insertRows(at: IndexSet(integer: at), withAnimation: animation)
            }
            
            return true;
        } else {
            self.moveItem(from: at, to: at)
        }
        
        return false;
        
    }
    
    public func addItem(item:TableRowItem, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Bool {
        return self.insert(item: item, at: self.count, redraw: redraw, animation:animation)
    }
    
    public func insert(items:[TableRowItem], at:Int, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Void {
        
        
        var current:Int = 0;
        for item in items {
            
            if(self.insert(item: item, at: at + current, redraw: false)) {
                current += 1;
            }
            
        }
        
        if(current != 0 && redraw) {
            self.tableView.insertRows(at: IndexSet(integersIn: at..<current), withAnimation: animation)
        }
        
    }
    
    func reloadData(row:Int) -> Void {
        if let view = self.viewNecessary(at: row) {
            let item = self.item(at: row)
            view.setItem(item: item, selected: item.isSelected)
            view.needsDisplay = true
        }
        //self.moveItem(from: row, to: row)
    }
    
    public func moveItem(from:Int, to:Int, changeItem:TableRowItem? = nil, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        
        var item:TableRowItem = self.item(at:from);
        
        if let change = changeItem {
            change.table = self
            self.listhash.removeValue(forKey: item.stableId)
            self.listhash[change.stableId] = change
            item = change
        }
        
        self.list.remove(at: from);
        self.list.insert(item, at: to);

        
        if(redraw) {
            
            if from == to {
                self.reloadData(row: to)
            } else {
                self.tableView.removeRows(at: IndexSet(integer:from), withAnimation: from == to ? .none : animation)
                self.tableView.insertRows(at: IndexSet(integer:to), withAnimation: from == to ? .none :  animation)
            }
            
        }
        
    }
    
    public func beginUpdates() -> Void {
        updating = true
        updateScroll()
        self.previousScroll = nil
    }
    
    public func endUpdates() -> Void {
        updating = false
        updateScroll()
        self.previousScroll = nil
    }
    
    public func rectOf(item:TableRowItem) -> NSRect {
        if let index = self.index(of: item) {
            return self.tableView.rect(ofRow: index)
        } else {
            return NSZeroRect
        }
    }
    
    func remove(item:TableRowItem, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Void {
        var pos:Int? = self.index(of: item);
        
        if let p = pos {
            self.list.remove(at: p);
            self.listhash.removeValue(forKey: item.stableId)
            
            if(redraw) {
                self.tableView.removeRows(at: IndexSet(integer:p), withAnimation: animation)
            }
        } else {
            
        }
        
    }
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Void {
        self.remove(item: self.item(at: at), redraw: redraw)
    }
    
    public func remove(range:Range<Int>, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Void {
        
        var sub:[TableRowItem] = Array(self.list[range])
        
        
        for item in sub {
            self.remove(item: item, redraw: false)
        }
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn:range), withAnimation: animation)
        }
    }
    
    public func removeAll(redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Void {
        var count:Int = self.count;
        self.list.removeAll()
        self.listhash.removeAll()
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn: 0..<count), withAnimation: animation)
        }
    }
    
    public func reloadData() -> Void {
        self.tableView.reloadData()
    }
    
    public func item(at:Int) -> TableRowItem {
        return self.list[at];
    }
    
    public func visibleRows(_ insetHeight:CGFloat = 0) -> NSRange {
        return self.tableView.rows(in: NSMakeRect(self.tableView.visibleRect.minX, self.tableView.visibleRect.minY, self.tableView.visibleRect.width, self.tableView.visibleRect.height + insetHeight))
    }
    
    public func viewNecessary(at row:Int) -> TableRowView? {
        return self.tableView.rowView(atRow: row, makeIfNecessary: false) as? TableRowView
    }
    
    
    public func select(item:TableRowItem) -> Bool {
        
        if(self.item(stableId:item.stableId) != nil && item.stableId != selectedhash.modify({$0})) {
            if(self.delegate?.isSelectable(row: item.index, item: item) == true) {
                self.cancelSelection();
                let _ = selectedhash.swap(item.stableId)
                item.prepare(true)
                self.reloadData(row:item.index)
                self.delegate?.selectionDidChange(row: item.index, item: item)
                return true;
            }
        }
        
        return false;
        
    }
    
    public func cancelSelection() -> Void {
        if let item = self.item(stableId: selectedhash.modify({$0})) {
            item.prepare(false)
            let _ = selectedhash.swap(-1)
            self.reloadData(row:item.index)
        } else {
            let _ = selectedhash.swap(-1)
        }
    }
    
    
    func rowView(item:TableRowItem) -> TableRowView {
        var identifier:String = NSStringFromClass(item.viewClass())
        var view = self.tableView.make(withIdentifier: identifier, owner: self.tableView)
        if(view == nil) {
            var vz = item.viewClass() as! TableRowView.Type
            
            view = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), item.height))
            
            view?.identifier = identifier
            
        }
        
        return view as! TableRowView;
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.count;
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return self.item(at: row).height
    }
    
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return false;
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        return nil
    }
    

    
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        var item:TableRowItem = self.item(at: row);
        
        var view:TableRowView = self.rowView(item: item);
        
        
        view.setItem(item: item, selected:self.selectedItem() == item)
        
        return view
    }
    
    func hashRects() -> [(Int64,NSRect)] {
        var hlist:[(Int64,NSRect)] = [(Int64,NSRect)]()

        for item in self.list {
            hlist.append(item.stableId,self.rectOf(item: item))
        }
        
        return hlist;
        
    }
    
    public func apply(transition:TableTransition) ->Void {
        self.merge(transition.deleted, transition.inserted, transition.animated, transition.scrollState)
    }
    
    public func merge(_ deleteIndexes:[Int], _ insertedIndexes:[(Int,TableRowItem,Int?)], _ animated:Bool = true,_ state:TableScrollState = .none(nil)) -> Void {
        
        
        assert(!self.updating)
            
        self.beginUpdates()
        
        let lhash = self.hashRects()
        let lsize = self.documentSize
        let loffset = self.documentOffset
        
        if(loffset.y < 0) {
            self.contentView.bounds = NSMakeRect(0, 0, 0, NSHeight(self.contentView.bounds))
        }
        
        self.tableView.beginUpdates()
        
        var inserted:[TableRowItem] = []
        var removed:[TableRowItem] = []
        
        var rd:Int = 0
        
        for rdx in deleteIndexes {
            
            var s:Bool = false
            
            for (_,_,prev) in insertedIndexes {
                
                if let p = prev {
                    s = rdx == p
                }
                
                if(s) {
                    break
                }
            }
            if(!s) {
                removed.append(self.item(at: rdx - rd))
                self.remove(at: rdx - rd, redraw: true, animation:animated ? .effectFade : .none)
                rd+=1
            }
        }
        
        
        for (idx,item,prev) in insertedIndexes {
            
            if let p = prev, let r = self.index(hash: item.stableId) {
                let _ = self.moveItem(from:r, to:idx, changeItem:item, redraw: true, animation:animated ? .effectFade : .none)
            } else {
                let _ = self.insert(item: item, at:idx, redraw: true, animation:animated ? .effectFade : .none)
                inserted.append(item)
            }
        }
        
        
        self.tableView.endUpdates()
        
        
        switch state {
        case let .none(animation):
           // print("scroll do nothing")
            animation?.animate(added: inserted, removed:removed)

        case let .save(animation):
            
            var noffset = self.documentOffset
            var nsize = self.documentSize
            var sitem:TableRowItem?
            var rect:NSRect = NSZeroRect
            var nrect:NSRect = NSZeroRect
            
            for (h,r) in lhash.reversed() {
                if let item = self.item(stableId: h) {
                    sitem = item
                    rect = r
                    nrect = self.rectOf(item: self.item(stableId: h)!)
                    break
                }
            }
            
            if let item = sitem {
                //let y = min(max(noffset.y - (NSMinY(rect) - NSMinY(nrect)),0),nsize.height - NSHeight(self.frame))
                
                let y = noffset.y - (NSMinY(rect) - NSMinY(nrect))
                
                
                
//                if y < 0 {
//                    var bp = 0
//                    bp += 1
//                }
                
               // NSLog("o:\(rect.minY), n:\(nrect.minY)")
                self.contentView.bounds = NSMakeRect(0, y, 0, NSHeight(self.contentView.bounds))
            }

            animation?.animate(added: inserted, removed:removed)
            
        case let .bottom(item,animation):
            break
        case let .top(item,animation):
            
            let rect = self.rectOf(item: item)
            
            self.contentView.bounds = NSMakeRect(0, rect.maxY - bounds.height, 0, self.contentView.bounds.height)
            
            animation?.animate(added: inserted, removed:removed)
            
            break
        case let .center(item,animation):
            break
        }
        
    

        self.endUpdates()
        
    }
    
    public func contentInteractionView(for stableId: Int64) -> NSView? {
        if let item = self.item(stableId: stableId) {
            let view = viewNecessary(at:item.index)
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                 return view.interactionContentView
            }
           
        }
        
        return nil
    }
    

    func selectRow(index: Int) {
        if self.count > index {
            self.select(item: self.item(at: index))
        }
    
    }
    
    public override func change(size: NSSize, animated: Bool, _ save:Bool = true) {
        
        let s = self.frame.size
        
        if animated {
            if !tableView.isFlipped {
                
                let y =  (s.height - size.height)
                
                CATransaction.begin()

              //  if y < 0 {
                    
                var presentBounds:NSRect = self.layer?.bounds ?? self.bounds
                var presentation = self.layer?.presentation()
                if let presentation = presentation, self.layer?.animation(forKey:"bounds") != nil {
                    presentBounds = presentation.bounds
                }
                
                self.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, self.bounds.minY, size.width, size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                
                
                
                if (y > 0) {
                    
                    
                    var presentBounds:NSRect = contentView.layer?.bounds ?? contentView.bounds
                    presentation = contentView.layer?.presentation()
                    if let presentation = presentation, contentView.layer?.animation(forKey:"bounds") != nil {
                        presentBounds = presentation.bounds
                    }
                    
                    presentBounds.size.height += y
                    
                    contentView.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, contentView.bounds.minY, size.width, size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                    
                }
                
                var currentY:CGFloat = 0
                
                presentation = contentView.layer?.presentation()
                if let presentation = presentation, contentView.layer?.animation(forKey:"position") != nil {
                    currentY = presentation.position.y
                }
                
                let pos = contentView.layer?.position ?? NSZeroPoint
                
                contentView.layer?.animatePosition(from: NSMakePoint(0,currentY + (y > 0 ? -y : y)), to: pos, duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                
                
                
                CATransaction.commit()
                
                self.setFrameSize(size)
                
            }
        }
        
    }
    
    

    
    public func setScrollHandler(_ handler: @escaping (_ scrollPosition:ScrollPosition) ->Void) -> Void {
        
        scrollHandler = handler
        
    }
    
    public func performScrollEvent() -> Void {
        self.updateScroll()
        NotificationCenter.default.post(name: NSNotification.Name.NSViewBoundsDidChange, object: self.contentView)
    }
    
}
