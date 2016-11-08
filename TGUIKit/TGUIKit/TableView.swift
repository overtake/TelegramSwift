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
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool;
    func isSelectable(row:Int, item:TableRowItem) -> Bool;
    
}

public enum TableScrollState :Equatable {
    case top(Int64, Bool); // stableId, animation
    case bottom(Int64, Bool); //  stableId, animation
    case center(Int64, Bool); //  stableId, animation
    case save(TableAnimationInterface?);
    case none(TableAnimationInterface?);
    case down(Bool);
    case up(Bool);
}

public func ==(lhs:TableScrollState, rhs:TableScrollState) -> Bool {
    switch lhs {
    case let .top(lhsStableId, lhsAnimated):
        switch rhs {
        case let .top(rhsStableId,rhsAnimated):
            return lhsStableId == rhsStableId && lhsAnimated == rhsAnimated
        default:
            return false
        }
    case let .bottom(lhsStableId, lhsAnimated):
        switch rhs {
        case let .bottom(rhsStableId,rhsAnimated):
            return lhsStableId == rhsStableId && lhsAnimated == rhsAnimated
        default:
            return false
        }
    case let .center(lhsStableId, lhsAnimated):
        switch rhs {
        case let .center(rhsStableId,rhsAnimated):
            return lhsStableId == rhsStableId && lhsAnimated == rhsAnimated
        default:
            return false
        }
    case let .down(lhsAnimated):
        switch rhs {
        case let .down(rhsAnimated):
            return lhsAnimated == rhsAnimated
        default:
            return false
        }
    case let .up(lhsAnimated):
        switch rhs {
        case let .up(rhsAnimated):
            return lhsAnimated == rhsAnimated
        default:
            return false
        }
    case let .save(_):
        switch rhs {
        case let .save(_):
            return true
        default:
            return false
        }
    case let .none(_):
        switch rhs {
        case let .none(_):
            return true
        default:
            return false
        }
    default:
        return false
    }
}

protocol SelectDelegate : class {
    func selectRow(index:Int) -> Void;
}

class TGFlipableTableView : NSTableView, CALayerDelegate {
    
    public var flip:Bool = true
    
    public weak var sdelegate:SelectDelegate?
    weak var table:TableView?
    var border:BorderType?
    
    override var isFlipped: Bool {
        return flip
    }
    
    override func draw(_ dirtyRect: NSRect) {
       
    }

    
    override func addSubview(_ view: NSView) {
        super.addSubview(view)
    }
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(self.bounds)
        
        if let border = border {
            
            ctx.setFillColor(NSColor.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, NSHeight(self.frame) - .borderSize, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, .borderSize, NSHeight(self.frame)))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(NSWidth(self.frame) - .borderSize, 0, .borderSize, NSHeight(self.frame)))
            }
            
        }
    }

    
    override func mouseDown(with event: NSEvent) {
        let point = self.convert(event.locationInWindow, from: nil)
        let range  = self.rows(in: NSMakeRect(point.x, point.y, 1, 1));
        sdelegate?.selectRow(index: range.location)

    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        if inLiveResize {
            if let table = table {
                table.layoutIfNeeded(with: table.visibleRows())
            }
        }
    }
    
    var liveWidth:CGFloat = 0
    
    override func viewWillStartLiveResize() {
        liveWidth = frame.width
    }
    
    override func viewDidEndLiveResize() {

        if liveWidth != frame.width && liveWidth != 0 {
            liveWidth = 0
            if let table = table {
                table.layoutIfNeeded(with: NSMakeRange(0, table.count))
            }
        }
        
    }
    
    
    override func mouseUp(with event: NSEvent) {
        
    }

}

public protocol InteractionContentViewProtocol : class {
    func contentInteractionView(for stableId: Int64) -> NSView?
}

open class TableView: ScrollView, NSTableViewDelegate,NSTableViewDataSource,SelectDelegate,InteractionContentViewProtocol {
    
    public var separator:TableSeparator = .none
    
    var list:[TableRowItem] = [TableRowItem]();
    var tableView:TGFlipableTableView
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
        
      //  self.tableView.layer?.drawsAsynchronously = System.drawAsync
        self.tableView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        

        super.init(frame: frameRect);
        
        table.table = self

        
        self.clipView.border = BorderType([.Right])
        self.tableView.border = BorderType([.Right])
       // self.tableView.usesStaticContents = true
        self.hasVerticalScroller = true;

        self.documentView = self.tableView;
        self.autoresizesSubviews = true;
        self.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewHeightSizable]
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.sdelegate = self

        self.updateTrackingAreas();
        

        
        var column:NSTableColumn = NSTableColumn(identifier: "column");
        column.width = NSWidth(frameRect)
        self.tableView.addTableColumn(column)

        self.tableView.headerView = nil;
        
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        
    }
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        
        super.draw(layer, in: ctx)
        
    }
    
    func layoutIfNeeded(with range:NSRange) {
        for i in range.min ..< range.max {
            let item = self.item(at: i)
            let before = item.height
            let updated = item.makeSize(tableView.frame.width)
            let after = item.height
            if before != after && updated {
                reloadData(row: i, animated: false)
                noteHeightOfRow(i, false)
            }
        }
    }
    
    open override func viewDidMoveToSuperview() {
        if let sv = superview {
            let clipView = self.contentView
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name.NSViewBoundsDidChange, object: clipView, queue: nil, using: { [weak self] notification  in
                if let strongSelf = self {
                    
                    let reqCount = strongSelf.count / 6
                    
                    strongSelf.updateStickAfterScroll()
                    
                    if (!strongSelf.updating && !strongSelf.clipView.isAnimateScrolling) {
                        
                        let scroll = strongSelf.scrollPosition
                    
                        
                        let range = strongSelf.tableView.rows(in: strongSelf.tableView.visibleRect)
                        
                        if(scroll.direction != strongSelf.previousScroll?.direction && scroll.rect != strongSelf.previousScroll?.rect) {
                            
                            switch(scroll.direction) {
                            case .top:
                                if(range.location  <=  reqCount) {
                                    strongSelf.scrollHandler(scroll)
                                    strongSelf.previousScroll = scroll

                                }
                            case .bottom:
                                if(strongSelf.count - (range.location + range.length) <= reqCount) {
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
    
    
    private var stickClass:AnyClass?
    private var stickView:TableStickView?
    private var stickItem:TableStickItem? {
        didSet {
            if stickItem != oldValue {
                if let stickHandler = stickHandler {
                    stickHandler(stickItem)
                }
            }
        }
    }
    private var stickHandler:((TableStickItem?)->Void)?
    
    public func set(stickClass:AnyClass?, handler:@escaping(TableStickItem?)->Void) {
        self.stickClass = stickClass
        self.stickHandler = handler
        if let stickClass = stickClass {
            if stickView == nil {
                var stickItem:TableStickItem?
                for item in list {
                    if item.isKind(of: stickClass) {
                        stickItem = item as? TableStickItem
                        break
                    }
                }
                if let stickItem = stickItem {
                    self.stickItem = stickItem
                    var vz = stickItem.viewClass() as! TableStickView.Type
                    stickView = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), stickItem.height))
                    stickView!.header = true
                    stickView!.set(item: stickItem, animated: true)
                    tableView.addSubview(stickView!)
                }
            }
            
            Queue.mainQueue().async {[weak self] in
                self?.updateStickAfterScroll()
            }
            
        } else {
            stickView?.removeFromSuperview()
            stickView = nil
            stickItem = nil
        }
    }
    
    func optionalItem(at:Int) -> TableRowItem? {
        return at < count ? self.item(at: at) : nil
    }
    
    func updateStickAfterScroll() -> Void {
        let range = self.visibleRows()
        
        if let stickClass = stickClass {
            if documentSize.height > frame.height {
                var index:Int = range.location + 1
                
                
                var scrollInset = self.documentOffset.y - frame.minY
                var item:TableRowItem? = optionalItem(at: index)
                
                if let s = item, !s.isKind(of: stickClass) {
                    index += 1
                    item = self.optionalItem(at: index)
                 }
                
                var currentStick:TableStickItem?
                
                for index in stride(from: range.location, to: -1, by: -1) {
                    let item = self.optionalItem(at: index)
                    if let item = item, item.isKind(of: stickClass) {
                        currentStick = item as? TableStickItem
                        break
                    }
                }
                
                if let currentStick = currentStick, stickView?.item != currentStick {
                    stickView?.set(item: currentStick, animated: true)
                    
                }
                
                stickItem = currentStick
                
                if let item = item {
                   
                    if let stickView = stickView {
                        if tableView.subviews.last != stickView {
                            stickView.removeFromSuperview()
                            tableView.addSubview(stickView)
                        }
                    }
                    
                    if item.isKind(of: stickClass) {
                        var rect:NSRect = tableView.rect(ofRow: index)
                        var dif:CGFloat = max(min(0, scrollInset - rect.minY), -item.height)
                        var yTopOffset:CGFloat = scrollInset - (dif + item.height)
                                            
                        stickView?.setFrameOrigin(0, max(0,yTopOffset))
                        stickView?.header = fabs(dif) == item.height
                    }
                    
                } else if let stickView = stickView {
                    stickView.setFrameOrigin(0, max(0,scrollInset))
                    stickView.header = true
                }
  
            }

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
    
    public func insert(item:TableRowItem, at:Int = 0, redraw:Bool = true, animation:NSTableViewAnimationOptions = NSTableViewAnimationOptions(rawValue: 0)) -> Bool {
        
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
    
    public func addItem(item:TableRowItem, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Bool {
        return self.insert(item: item, at: self.count, redraw: redraw, animation:animation)
    }
    
    public func insert(items:[TableRowItem], at:Int = 0, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        
        
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
    
    public var firstItem:TableRowItem? {
        return self.list.first
    }
    
    public var lastItem:TableRowItem? {
        return self.list.last
    }
    
    public func noteHeightOfRow(_ row:Int, _ animated:Bool = true) {
        if !animated {
            NSAnimationContext.current().duration = 0
        }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
    }
    
    public func reloadData(row:Int, animated:Bool = false) -> Void {
        if let view = self.viewNecessary(at: row) {
            let item = self.item(at: row)
            
            if let viewItem = view.item {
                if viewItem.height != item.height {
                    tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
                
            }
            
            view.set(item: item, animated: animated)
            view.layer?.setNeedsDisplay()
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
    
    func remove(item:TableRowItem, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
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
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        self.remove(item: self.item(at: at), redraw: redraw, animation:animation)
    }
    
    public func remove(range:Range<Int>, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        
        var sub:[TableRowItem] = Array(self.list[range])
        
        
        for item in sub {
            self.remove(item: item, redraw: false)
        }
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn:range), withAnimation: animation)
        }
    }
    
    public func removeAll(redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        var count:Int = self.count;
        self.list.removeAll()
        self.listhash.removeAll()
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn: 0..<count), withAnimation: animation)
        }
    }
    
    public func selectNext(_ scroll:Bool = false, _ animated:Bool = false) -> Void {
        let hash = selectedhash.modify({$0})
        if hash != -1 {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex += 1
                
                if selectedIndex == count  {
                   selectedIndex = 0
                }
                
                 select(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let firstItem = firstItem {
                self.select(item: firstItem)
            }
        }
        if selectedhash.modify({$0}) != -1 {
            self.scroll(to: .top(selectedhash.modify({$0}), true), inset: EdgeInsets(), true)
        }
    }
    
    public func selectPrev(_ scroll:Bool = false, _ animated:Bool = false) -> Void {
        let hash = selectedhash.modify({$0})
        if hash != -1 {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex -= 1
                
                if selectedIndex == -1  {
                    selectedIndex = count - 1
                }
                
                select(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let lastItem = lastItem {
                self.select(item: lastItem)
            }
        }
        
        if selectedhash.modify({$0}) != -1 {
            self.scroll(to: .bottom(selectedhash.modify({$0}), animated), inset: EdgeInsets(), true)
        }
    }
    
    public var isEmpty:Bool {
        return self.list.isEmpty
    }
    
    public func reloadData() -> Void {
        self.tableView.reloadData()
    }
    
    public func item(at:Int) -> TableRowItem {
        return self.list[at]
    }
    
    public func visibleRows(_ insetHeight:CGFloat = 0) -> NSRange {
        return self.tableView.rows(in: NSMakeRect(self.tableView.visibleRect.minX, self.tableView.visibleRect.minY, self.tableView.visibleRect.width, self.tableView.visibleRect.height + insetHeight))
    }
    
    public func viewNecessary(at row:Int) -> TableRowView? {
        return self.tableView.rowView(atRow: row, makeIfNecessary: false) as? TableRowView
    }
    
    
    public func select(item:TableRowItem, notify:Bool = true) -> Bool {
        
        if(self.item(stableId:item.stableId) != nil && item.stableId != selectedhash.modify({$0})) {
            if(self.delegate?.isSelectable(row: item.index, item: item) == true) {
                self.cancelSelection();
                let _ = selectedhash.swap(item.stableId)
                item.prepare(true)
                self.reloadData(row:item.index)
                if notify {
                    self.delegate?.selectionDidChange(row: item.index, item: item)
                }
                return true;
            }
        }
        
        return false;
        
    }
    
    public func changeSelection(stableId:Int64?) {
        if let stableId = stableId {
            if let item = self.item(stableId: stableId) {
                self.select(item:item, notify:false)
            } else {
                cancelSelection()
                self.selectedhash.swap(stableId)
            }
        } else {
            cancelSelection()
        }
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
        
        
        view.set(item: item, animated:false)
        
        return view
    }
    
    func hashRects() -> [(Int64,NSRect)] {
        var hlist:[(Int64,NSRect)] = [(Int64,NSRect)]()

        for item in self.list {
            hlist.append(item.stableId,self.rectOf(item: item))
        }
        
        return hlist;
        
    }
    
    func itemRects() -> [(TableRowItem, NSRect, Int)] {
        var ilist:[(TableRowItem,NSRect,Int)] = [(TableRowItem,NSRect,Int)]()
        
        for item in self.list {
            ilist.append((item,self.rectOf(item: item), index(of: item)!))
            
        }
        
        return ilist;
        
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
        
//        if(loffset.y < 0) {
//            self.contentView.bounds = NSMakeRect(0, 0, 0, NSHeight(self.contentView.bounds))
//        }
        
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
                
                let effect:NSTableViewAnimationOptions
                if case let .none(interface) = state {
                    effect = .effectFade
                } else {
                    effect = animated ? .effectFade : .none
                }
                self.remove(at: rdx - rd, redraw: true, animation:effect)
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
                let y = noffset.y - (NSMinY(rect) - NSMinY(nrect))
               // clipView.scroll(to: NSMakePoint(0, y))
                self.contentView.bounds = NSMakeRect(0, y, 0, NSHeight(self.contentView.bounds))
                reflectScrolledClipView(clipView)
            }

            animation?.animate(added: inserted, removed:removed)
            
        case .bottom(_,_), .top(_,_), .center(_,_):
            self.scroll(to:state)
        case .up(_), .down(_):
            self.scroll(to:state)
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
            if let delegate = delegate, delegate.selectionWillChange(row: index, item: self.item(at: index)) {
                self.select(item: self.item(at: index))
            }
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
            
            }
        }
        
        self.setFrameSize(size)
    }
    
    
    
    public func scroll(to state:TableScrollState, inset:EdgeInsets = EdgeInsets(), _ toVisible:Bool = false) {
       // if let index = self.index(of: item) {
        
            var item:TableRowItem?
            var animate:Bool = false

            switch state {
            case let .bottom(stableId,animation), let .top(stableId,animation), let .center(stableId,animation):
                item = self.item(stableId: stableId)
                animate = animation
            case let .down(animation):
                if !tableView.isFlipped {
                    clipView.scroll(to: NSMakePoint(0, 0), animated:animation)
                } else {
                    clipView.scroll(to: NSMakePoint(0, max(0,documentSize.height - frame.height)), animated:animation)
                }
                return
            case let .up(animation):
                if !tableView.isFlipped {
                    clipView.scroll(to: NSMakePoint(0, max(documentSize.height,frame.height)), animated:animation)
                } else {
                   clipView.scroll(to: NSMakePoint(0, 0), animated:animation)
                }
                return
            default:
                fatalError("for scroll to item, you can use only .top, center, .bottom enumeration")
            }
        
        if let item = item {
            var rowRect = self.rectOf(item: item)
            
            let height:CGFloat = self is HorizontalTableView ? frame.width : frame.height
            
            switch state {
            case let .bottom(stableId, _):
                if tableView.isFlipped {
                    rowRect.origin.y -= (height - rowRect.height)
                }
            case let .top(stableId, _):
                if !tableView.isFlipped {
                    rowRect.origin.y += height
                }
            case let .center(stableId, _):
                if !tableView.isFlipped {
                    rowRect.origin.y -= floorToScreenPixels((height - rowRect.height) / 2.0)
                } else {
                    
                    if rowRect.maxY > height/2.0 {
                        rowRect.origin.y += floorToScreenPixels((height) / 2.0) - rowRect.height - rowRect.height/2.0 
                    } else {
                        rowRect.origin.y = self is HorizontalTableView ? frame.minY : 0
                    }
                    

                   // fatalError("not implemented")
                }
    
            default:
                fatalError("not implemented")
            }
            
            if toVisible {
                let view = self.viewNecessary(at: item.index)
                if let view = view, view.visibleRect.height == item.height {
                    return
                }
            }
            
            clipView.scroll(to: NSMakePoint(0, min(max(rowRect.minY,0), documentSize.height - height) + inset.top), animated:animate)
            
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
