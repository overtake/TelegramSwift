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

public class UpdateTransition<T> {
    public let inserted:[(Int,T)]
    public let updated:[(Int,T)]
    public let deleted:[Int]
    
    public init(deleted:[Int], inserted:[(Int,T)], updated:[(Int,T)]) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
    }
    
    public var isEmpty:Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
}


public class TableUpdateTransition : UpdateTransition<TableRowItem> {
    public let state:TableScrollState
    public let animated:Bool
    public let grouping:Bool
    
    public init(deleted:[Int], inserted:[(Int,TableRowItem)], updated:[(Int,TableRowItem)], animated:Bool = false, state:TableScrollState = .none(nil), grouping:Bool = true) {
        self.animated = animated
        self.state = state
        self.grouping = grouping
        super.init(deleted: deleted, inserted: inserted, updated: updated)
    }
    
    
}

public final class TableEntriesTransition<T> : TableUpdateTransition {
    public let entries:T
    public init(deleted:[Int], inserted:[(Int,TableRowItem)], updated:[(Int,TableRowItem)], entries:T, animated:Bool = false, state:TableScrollState = .none(nil), grouping:Bool = true) {
        self.entries = entries
        super.init(deleted: deleted, inserted: inserted, updated: updated, animated:animated, state: state, grouping:grouping)
    }
}

public protocol TableViewDelegate : class {
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void;
    func selectionWillChange(row:Int, item:TableRowItem) -> Bool;
    func isSelectable(row:Int, item:TableRowItem) -> Bool;
    
}

public enum TableSavingSide {
    case lower
    case upper
}

public enum TableScrollState :Equatable {
    case top(AnyHashable, Bool); // stableId, animation
    case bottom(AnyHashable, Bool); //  stableId, animation
    case center(AnyHashable, Bool); //  stableId, animation
    case saveVisible(TableSavingSide)
    case none(TableAnimationInterface?);
    case down(Bool);
    case up(Bool);
}

public extension TableScrollState {
    public func swap(to stableId:AnyHashable) -> TableScrollState {
        switch self {
        case let .top(_, animated):
            return .top(stableId, animated)
        case let .bottom(_, animated):
            return .bottom(stableId, animated)
        case let .center(_, animated):
            return .center(stableId, animated)
        default:
            return self
        }
    }
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
    case .none:
        switch rhs {
        case .none:
            return true
        default:
            return false
        }
    case let .saveVisible(lhsType):
        switch rhs {
        case let .saveVisible(rhsType):
            return lhsType == rhsType
        default:
            return false
        }
    }
}

protocol SelectDelegate : class {
    func selectRow(index:Int) -> Void;
}

class TGFlipableTableView : NSTableView, CALayerDelegate {
    
    var bottomInset:CGFloat = 0
    
    public var flip:Bool = true
    
    public weak var sdelegate:SelectDelegate?
    weak var table:TableView?
    var border:BorderType?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.autoresizesSubviews = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var isFlipped: Bool {
        return flip
    }
    
    override func draw(_ dirtyRect: NSRect) {
       
    }

    override public func setNeedsDisplay(_ invalidRect: NSRect) {
        
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
        let oldWidth: CGFloat = frame.width
        super.setFrameSize(newSize)
        
        if oldWidth != frame.width {
            if let table = table {
                table.layoutIfNeeded(with: table.visibleRows(), oldWidth: oldWidth)
            }
        }
    }
    
    
    
    var liveWidth:CGFloat = 0
    
    override func viewWillStartLiveResize() {
        liveWidth = frame.width
    }
    
    override func viewDidEndLiveResize() {
        if liveWidth  != frame.width {
            liveWidth = 0
            table?.layoutItems()
        }
    }
    
    
    override func mouseUp(with event: NSEvent) {
        
    }

}

public protocol InteractionContentViewProtocol : class {
    func contentInteractionView(for stableId: AnyHashable) -> NSView?
}

public class TableScrollListener : NSObject {
    fileprivate let uniqueId:UInt32 = arc4random()
    fileprivate let handler:(ScrollPosition)->Void
    
    public init(_ handler:@escaping(ScrollPosition)->Void) {
        self.handler = handler
    }
    
}

open class TableView: ScrollView, NSTableViewDelegate,NSTableViewDataSource,SelectDelegate,InteractionContentViewProtocol {
    
    public var separator:TableSeparator = .none
    
    var list:[TableRowItem] = [TableRowItem]();
    var tableView:TGFlipableTableView
    weak public var delegate:TableViewDelegate?
    private var trackingArea:NSTrackingArea?
    private var listhash:[AnyHashable:TableRowItem] = [AnyHashable:TableRowItem]();
    
    private let mergePromise:Promise<TableUpdateTransition> = Promise()
    private let mergeDisposable:MetaDisposable = MetaDisposable()
   
    public let selectedhash:Atomic<AnyHashable?> = Atomic(value: nil);
   
    private var updating:Bool = false
    
    private var previousScroll:ScrollPosition?
    public var needUpdateVisibleAfterScroll:Bool = false
    private var scrollHandler:(_ scrollPosition:ScrollPosition) ->Void = {_ in}
    
    
    private var scrollListeners:[TableScrollListener] = []
    
    
    public var emptyItem:TableRowItem? {
        didSet {
            if let _ = emptyView {
                updateEmpties()
            }
        }
    }
    private var emptyView:TableRowView?
    
    public func addScroll(listener:TableScrollListener) {
        scrollListeners.append(listener)
    }
    
    
    public var bottomInset:CGFloat = 0 {
        didSet {
            tableView.bottomInset = bottomInset
        }
    }
    
    
    
    public func removeScroll(listener:TableScrollListener) {
        var index:Int = 0
        var found:Bool = false
        for enumerate in scrollListeners {
            if enumerate.uniqueId == listener.uniqueId {
                found = true
                break
            }
            index += 1
        }
        
        if found {
            scrollListeners.remove(at: index)
        }
        
    }
    
    public var count:Int {
        get {
            return self.list.count
        }
    }
    
    open override func setNeedsDisplay(_ invalidRect: NSRect) {
        
    }

    open override var isFlipped: Bool {
        return true
    }
    
    convenience override init(frame frameRect: NSRect) {
        self.init(frame:frameRect, isFlipped:true, drawBorder: false)
    }
    
    public var border:BorderType? {
        didSet {
            self.clipView.border = border
            self.tableView.border = border
        }
    }
    
    public required init(frame frameRect: NSRect, isFlipped:Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {

        let table = TGFlipableTableView.init(frame:frameRect);
        table.flip = isFlipped
        
        self.tableView = table
        self.tableView.wantsLayer = true
        
        self.tableView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        

        super.init(frame: frameRect);
        
        table.table = self
        
        self.bottomInset = bottomInset
        table.bottomInset = bottomInset
        
        if drawBorder {
            self.clipView.border = BorderType([.Right])
            self.tableView.border = BorderType([.Right])
        }
     
        self.hasVerticalScroller = true;

        self.documentView = self.tableView;
        self.autoresizesSubviews = true;
        self.autoresizingMask = [.viewWidthSizable, .viewHeightSizable]
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.sdelegate = self
        self.tableView.allowsColumnReordering = true
        self.tableView.headerView = nil;
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        
        
        
        mergeDisposable.set(mergePromise.get().start(next: { [weak self] (transition) in
            self?.merge(with: transition)
        }))
        
    }
    
    
    open override func layout() {
        super.layout()
        emptyView?.frame = bounds
        if needsLayouItemsOnNextTransition {
            layoutItems()
        }
    }
    
    open override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
    }
    
    func layoutIfNeeded(with range:NSRange, oldWidth:CGFloat) {
        for i in range.min ..< range.max {
            let item = self.item(at: i)
            let before = item.height
            let updated = item.makeSize(tableView.frame.width, oldWidth: oldWidth)
            let after = item.height
            if (before != after && updated) || item.instantlyResize {
                reloadData(row: i, animated: false)
                noteHeightOfRow(i, false)
            }
        }
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
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
                    //if !strongSelf.clipView.isAnimateScrolling {
                        for listener in strongSelf.scrollListeners {
                            listener.handler(strongSelf.scrollPosition)
                        }
                   // }
                    
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
                    let vz = stickItem.viewClass() as! TableStickView.Type
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
    
    private var needsLayouItemsOnNextTransition:Bool = false
   
    public func layouItemsOnNextTransition() {
        needsLayouItemsOnNextTransition = true
    }
    
    public func layoutItems() {

        let visible = visibleItems()
        
        beginTableUpdates()
        enumerateItems { item in
            _ = item.makeSize(frame.width, oldWidth: item.width)
            reloadData(row: item.index, animated: false)
            NSAnimationContext.current().duration =  0.0
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: item.index))
            return true
        }
        endTableUpdates()
        
        if let visible = visible.last, !tableView.isFlipped {
            if let keys = layer?.animationKeys(), keys.isEmpty {
                if let item = self.item(stableId: visible.0.stableId) {
                    let nrect = rectOf(item: item)
                    
                    let y:CGFloat = nrect.minY - (frame.height - visible.1) + nrect.height
                    
                    self.contentView.bounds = NSMakeRect(0, y, 0, clipView.bounds.height)
                    reflectScrolledClipView(clipView)
                }
            }
            
        }
        
        needsLayouItemsOnNextTransition = false
    }
    
    func updateStickAfterScroll() -> Void {
        let range = self.visibleRows()
        
        if let stickClass = stickClass {
            if documentSize.height > frame.height {
                var index:Int = range.location + 1
                
                
                let scrollInset = self.documentOffset.y - frame.minY
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
                    
                    stickView?.setFrameSize(tableView.frame.width, item.height)
                    
                    if item.isKind(of: stickClass) {
                        let rect:NSRect = tableView.rect(ofRow: index)
                        let dif:CGFloat = max(min(0, scrollInset - rect.minY), -item.height)
                        let yTopOffset:CGFloat = scrollInset - (dif + item.height)
                                            
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

    public var topVisibleRow:Int? {
        let visible = visibleItems()
        if !isFlipped {
            return visible.first?.0.index
        } else {
            return visible.last?.0.index
        }
    }
    
    public var bottomVisibleRow:Int? {
        let visible = visibleItems()
        if isFlipped {
            return visible.first?.0.index
        } else {
            return visible.last?.0.index
        }
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
        if let hash = hash {
            return self.item(stableId:hash)
        }
        return nil
    }
    
    public func isSelected(_ item:TableRowItem) ->Bool {
        return selectedhash.modify({$0}) == item.stableId
    }
    
    public func item(stableId:AnyHashable) -> TableRowItem? {
        return self.listhash[stableId];
    }
    
    public func index(of:TableRowItem) -> Int? {
        
        if let it = self.listhash[of.stableId] {
            return self.list.index(of: it);
        }
        
        return nil
    }
    
    public func index(hash:AnyHashable) -> Int? {
        
        if let it = self.listhash[hash] {
            return self.list.index(of: it);
        }
        
        return nil
    }
    
    public func insert(item:TableRowItem, at:Int = 0, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Bool {
        
        assert(self.item(stableId:item.stableId) == nil, "inserting existing row inTable: \(self.item(stableId:item.stableId)!.className), new: \(item.className)")
        self.listhash[item.stableId] = item;
        self.list.insert(item, at: at);
        item.table = self;
        
        let animation = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current().duration = animation != .none ? NSAnimationContext.current().duration : 0.0
        
        if(redraw) {
            self.tableView.insertRows(at: IndexSet(integer: at), withAnimation: animation)
        }
        
        return true;
        
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
            self.tableView.insertRows(at: IndexSet(integersIn: at ..< current + at), withAnimation: animation)
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
                    NSAnimationContext.current().duration = animated ? 0.2 : 0.0
                    tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
            } else {
                NSAnimationContext.current().duration = animated ? 0.2 : 0.0
                tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
            }
            
            view.set(item: item, animated: animated)
            view.needsDisplay = true
            //view.needsLayout = true
        } else {
            NSAnimationContext.current().duration = 0.0
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        }
        //self.moveItem(from: row, to: row)
    }
    
    public func moveItem(from:Int, to:Int, changeItem:TableRowItem? = nil, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        
        
        var item:TableRowItem = self.item(at:from);
        let animation = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current().duration = animation != .none ? NSAnimationContext.current().duration : 0.0
       
        if let change = changeItem {
            assert(change.stableId == item.stableId)
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
        CATransaction.begin()
    }
    
    public func endUpdates() -> Void {
        updating = false
        updateScroll()
        self.previousScroll = nil
        CATransaction.commit()
    }
    
    public func rectOf(item:TableRowItem) -> NSRect {
        if let index = self.index(of: item) {
            return self.tableView.rect(ofRow: index)
        } else {
            return NSZeroRect
        }
    }
    
    public func rectOf(index:Int) -> NSRect {
        return self.tableView.rect(ofRow: index)
    }
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        let item = self.item(at: at)
        let animation = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current().duration = animation == .none ? 0.0 : NSAnimationContext.current().duration
        
        self.list.remove(at: at);
        self.listhash.removeValue(forKey: item.stableId)
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integer:at), withAnimation: animation)
        }
    }
    
    public func remove(range:Range<Int>, redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        
        for i in range.lowerBound ..< range.upperBound {
            remove(at: i, redraw: false)
        }
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn:range), withAnimation: animation)
        }
    }
    

    
    public func removeAll(redraw:Bool = true, animation:NSTableViewAnimationOptions = .none) -> Void {
        let count:Int = self.count;
        self.list.removeAll()
        self.listhash.removeAll()
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn: 0 ..< count), withAnimation: animation)
        }
    }
    
    public func selectNext(_ scroll:Bool = true, _ animated:Bool = false) -> Void {
        
        if let hash = selectedhash.modify({$0}) {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex += 1
                
                if selectedIndex == count  {
                   selectedIndex = 0
                }
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in sIndex ..< list.count {
                        if delegate.selectionWillChange(row: i, item: item(at: i)) {
                            selectedIndex = i
                            break
                        }
                    }
                }
                
                
                 _ = select(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let delegate = delegate {
                for item in list {
                    if delegate.selectionWillChange(row: item.index, item: item) {
                        _ = self.select(item: item)
                        break
                    }
                }
            }
            
        }
        if let hash = selectedhash.modify({$0}), scroll {
            self.scroll(to: .top(hash, animated), inset: EdgeInsets(), true)
        }
    }
    
    public func selectPrev(_ scroll:Bool = true, _ animated:Bool = false) -> Void {
        
        if let hash = selectedhash.modify({$0}) {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex -= 1
                
                if selectedIndex == -1  {
                    selectedIndex = count - 1
                }
                
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in stride(from: sIndex, to: -1, by: -1) {
                        if delegate.selectionWillChange(row: i, item: item(at: i)) {
                            selectedIndex = i
                            break
                        }
                    }
                }

                
                _ = select(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let delegate = delegate {
                for i in stride(from: list.count - 1, to: -1, by: -1) {
                    if delegate.selectionWillChange(row: i, item: item(at: i)) {
                        _ = self.select(item: item(at: i))
                        break
                    }
                }
            }

        }
        
        if let hash = selectedhash.modify({$0}), scroll {
            self.scroll(to: .bottom(hash, animated), inset: EdgeInsets(), true)
        }
    }
    
    public var isEmpty:Bool {
        return self.list.isEmpty || (!tableView.isFlipped && list.count == 1)
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
    
    public var listHeight:CGFloat {
        var height:CGFloat = 0
        for item in list {
            height += item.height
        }
        return height
    }
    
    public func row(at point:NSPoint) -> Int {
        return tableView.row(at: NSMakePoint(point.x, point.y - bottomInset))
    }
    
    public func viewNecessary(at row:Int) -> TableRowView? {
        if row < 0 || row > count - 1 {
            return nil
        }
        return self.tableView.rowView(atRow: row, makeIfNecessary: false) as? TableRowView
    }
    
    
    public func select(item:TableRowItem, notify:Bool = true, byClick:Bool = false) -> Bool {
        
        if let delegate = delegate, delegate.isSelectable(row: item.index, item: item) {
            if(self.item(stableId:item.stableId) != nil) {
                if delegate.selectionWillChange(row: item.index, item: item) {
                    let new = item.stableId != selectedhash.modify({$0})
                    self.cancelSelection();
                    let _ = selectedhash.swap(item.stableId)
                    item.prepare(true)
                    self.reloadData(row:item.index)
                    if notify {
                        delegate.selectionDidChange(row: item.index, item: item, byClick:byClick, isNew:new)
                    }
                    return true;
                }
                
            }
            
        }
        return false;
        
    }
    
    public func changeSelection(stableId:AnyHashable?) {
        if let stableId = stableId {
            if let item = self.item(stableId: stableId) {
                _ = self.select(item:item, notify:false)
            } else {
                cancelSelection()
                _ = self.selectedhash.swap(stableId)
            }
        } else {
            cancelSelection()
        }
    }
    
    public func cancelSelection() -> Void {
        if let hash = selectedhash.modify({$0}) {
            if let item = self.item(stableId: hash) {
                item.prepare(false)
                let _ = selectedhash.swap(nil)
                self.reloadData(row:item.index)
            } else {
                let _ = selectedhash.swap(nil)
            }
        }
        
    }
    
    
    func rowView(item:TableRowItem) -> TableRowView {
        let identifier:String = item.identifier
        var view = self.tableView.make(withIdentifier: identifier, owner: self.tableView)
        if(view == nil) {
            let vz = item.viewClass() as! TableRowView.Type
            
            view = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), item.height))
            
            view?.identifier = identifier
            
        } 
        
        return view as! TableRowView;
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.count;
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return max(self.item(at: row).height, 1)
    }
    
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return false;
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        return nil
    }
    
  
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let item:TableRowItem = self.item(at: row);
        
        let view:TableRowView = self.rowView(item: item);
        
        
        view.set(item: item, animated: false)
        
        return view
    }

    
    func visibleItems() -> [(TableRowItem,CGFloat,CGFloat)]  { // item, top offset, bottom offset
        
        var list:[(TableRowItem,CGFloat,CGFloat)] = []
        
        let visible = visibleRows()
        
        for i in visible.location ..< visible.location + visible.length {
            let item = self.item(at: i)
            let rect = rectOf(index: i)
            if rect.height == item.height {
                if !tableView.isFlipped {
                    let top = frame.height - (rect.minY - documentOffset.y) - rect.height
                    let bottom = (rect.minY - documentOffset.y)
                    list.append(item,top,bottom)
                } else {
                    let top = rect.minY - documentOffset.y
                    let bottom = frame.height - (rect.minY - documentOffset.y) - rect.height
                    list.append(item,top,bottom)
                    //fatalError("not supported")
                }
            }
            
           // list.append(item,)
        }
        
        
        return list;

    }
    
    func itemRects() -> [(TableRowItem, NSRect, Int)] {
        var ilist:[(TableRowItem,NSRect,Int)] = [(TableRowItem,NSRect,Int)]()
        
        for i in 0 ..< self.list.count {
            ilist.append((item(at: i),self.rectOf(index: i), i))
            
        }
        
        return ilist;
        
    }
    
    public func beginTableUpdates() {
        self.tableView.beginUpdates()
    }
    
    public func endTableUpdates() {
        self.tableView.endUpdates()
    }
    
    public func stopMerge() {
        mergeDisposable.set(nil)
        mergePromise.set(.single(TableUpdateTransition(deleted: [], inserted: [], updated: [])))
    }
    
    public func startMerge() {
        mergeDisposable.set((mergePromise.get() |> deliverOnMainQueue).start(next: { [weak self] transition in
            self?.merge(with: transition)
        }))
    }
    
    public func merge(with transition:Signal<TableUpdateTransition, Void>) {
        mergePromise.set(transition)
    }
    
    private var first:Bool = true
    
    public func merge(with transition:TableUpdateTransition) -> Void {
        
        assertOnMainThread()
        assert(!updating)
        
        let oldEmpty = self.isEmpty
        
        self.beginUpdates()
        
        
        
        let visibleItems = self.visibleItems()
        if transition.grouping && !transition.isEmpty {
            self.tableView.beginUpdates()
        }
        
        var inserted:[TableRowItem] = []
        
        for rdx in transition.deleted.reversed() {
            let effect:NSTableViewAnimationOptions
            if case let .none(interface) = transition.state, interface != nil {
                effect = .effectFade
            } else {
                effect = transition.animated ? .effectFade : .none
            }
            self.remove(at: rdx, redraw: true, animation:effect)
        }
        
        NSAnimationContext.current().duration = transition.animated ? 0.2 : 0.0
        

        
        for (idx,item) in transition.inserted {
            _ = self.insert(item: item, at:idx, redraw: true, animation: transition.animated ? .effectFade : .none)
            if item.animatable {
                inserted.append(item)
            }
        }
       
        
        
        for (index,item) in transition.updated {
            let animated:Bool
            if case .none = transition.state {
                animated = true
            } else {
                animated = false
            }
            replace(item:item, at:index, animated: animated)
        }

        
        if transition.grouping && !transition.isEmpty {
            self.tableView.endUpdates()
        }
        
        //reflectScrolledClipView(clipView)
        switch transition.state {
        case let .none(animation):
            // print("scroll do nothing")
            animation?.animate(table:self, added: inserted, removed:[])
            
        case .bottom(_,_), .top(_,_), .center(_,_):
            self.scroll(to: transition.state)
        case .up(_), .down(_):
            self.scroll(to: transition.state)
        case let .saveVisible(side):
            
            if transition.isEmpty {
                break
            }

            var nrect:NSRect = NSZeroRect
            
            let strideTo:StrideTo<Int>
            
            if !tableView.isFlipped {
                switch side {
                case .lower:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .upper:
                    strideTo = stride(from: 0, to: visibleItems.count - 1, by: 1)
                }
            } else {
                switch side {
                case .upper:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .lower:
                    strideTo = stride(from: 0, to: visibleItems.count - 1, by: 1)
                }
            }

            
            for i in strideTo {
                let visible = visibleItems[i]
                if let item = self.item(stableId: visible.0.stableId) {
                    
                    nrect = rectOf(item: item)
                    
                    if let view = viewNecessary(at: i) {
                        if view.isInsertionAnimated {
                            break
                        }
                    }
                    
                    let y:CGFloat
                    
                    switch side {
                    case .lower:
                        if !tableView.isFlipped {
                            y = nrect.minY - (frame.height - visible.1) + nrect.height
                        } else {
                            y = nrect.minY - visible.1
                        }
                        break
                    case .upper:
                        if !tableView.isFlipped {
                            y = nrect.minY - (frame.height - visible.1) + nrect.height
                        } else {
                            y = nrect.minY - visible.1
                        }
                        break
                    }
                                        
                    self.contentView.bounds = NSMakeRect(0, y, 0, clipView.bounds.height)
                    reflectScrolledClipView(clipView)
                    break
                }
            }
            
            break
        }
        
        
        self.endUpdates()
        
        if oldEmpty != isEmpty || first {
            updateEmpties()
        }
        
        first = false
        performScrollEvent()
    }
    
    func updateEmpties() {
        if let emptyItem = emptyItem {
            if isEmpty {
                if let empt = emptyView, !empt.isKind(of: emptyItem.viewClass()) || empt.item != emptyItem {
                    emptyView?.removeFromSuperview()
                    emptyView = nil
                }
                if emptyView == nil {
                    let vz = emptyItem.viewClass() as! TableRowView.Type
                    emptyView = vz.init(frame:bounds)
                    emptyView?.identifier = identifier
                }
                emptyView?.frame = bounds
                if emptyView?.superview == nil {
                    addSubview(emptyView!)
                }
                emptyView?.set(item: emptyItem)
                emptyView?.needsLayout = true
            } else {
                emptyView?.removeFromSuperview()
                emptyView = nil
            }
        }
        
    }
    
    
    public func replace(item:TableRowItem, at index:Int, animated:Bool) {
        list[index] = item
        listhash[item.stableId] = item
        item.table = self
        reloadData(row: index, animated: animated)
    }

    public func contentInteractionView(for stableId: AnyHashable) -> NSView? {
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
            _ = self.select(item: self.item(at: index), byClick:true)
        }
    }
    
    public override func change(size: NSSize, animated: Bool, _ save:Bool = true) {
        
        if animated {

            if !tableView.isFlipped {
                
                CATransaction.begin()
                var presentBounds:NSRect = self.layer?.bounds ?? self.bounds
                let presentation = self.layer?.presentation()
                if let presentation = presentation, self.layer?.animation(forKey:"bounds") != nil {
                    presentBounds = presentation.bounds
                }
                
                self.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, self.bounds.minY, size.width, size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                let y = (size.height - presentBounds.height)
                
                presentBounds = contentView.layer?.bounds ?? contentView.bounds
                if let presentation = contentView.layer?.presentation(), contentView.layer?.animation(forKey:"bounds") != nil {
                    presentBounds = presentation.bounds
                }
                
                if y > 0 {
                    presentBounds.origin.y -= y
                    presentBounds.size.height += y
                } else {
                    presentBounds.origin.y += y
                    presentBounds.size.height -= y
                }
                
                contentView.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, contentView.bounds.minY, size.width, size.height), duration: 0.2, timingFunction: kCAMediaTimingFunctionEaseOut)
                CATransaction.commit()
            } else {
                super.change(size: size, animated: animated)
                return
            }
        }
        self.setFrameSize(size)
    }
    
    
    
    public func scroll(to state:TableScrollState, inset:EdgeInsets = EdgeInsets(), _ toVisible:Bool = false) {
       // if let index = self.index(of: item) {
        

        
            var item:TableRowItem?
            var animate:Bool = false

            switch state {
            case let .center(stableId,animation):
                item = self.item(stableId: stableId)
                animate = animation
            case let .bottom(stableId,animation):
                item = self.item(stableId: stableId)
                animate = animation
            case let .top(stableId,animation):
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
        
        let bottomInset = self.bottomInset != 0 ? (self.bottomInset) : 0
        
        if let item = item {
            var rowRect = self.rectOf(item: item)
            
            let height:CGFloat = self is HorizontalTableView ? frame.width : frame.height
            
            switch state {
            case  .bottom(_, _):
                if tableView.isFlipped {
                    rowRect.origin.y -= (height - rowRect.height) - bottomInset
                }
            case  .top(_, _):
               // break
                if !tableView.isFlipped {
                    rowRect.origin.y -= (height - rowRect.height) - bottomInset
                }
            case .center(_, _):
                if !tableView.isFlipped {
                    rowRect.origin.y -= floorToScreenPixels((height - rowRect.height) / 2.0) - bottomInset
                } else {
                    
                    if rowRect.maxY > height/2.0 {
                        rowRect.origin.y -= floorToScreenPixels((height - rowRect.height) / 2.0) - bottomInset
                    } else {
                        rowRect.origin.y = 0
                    }
                    

                   // fatalError("not implemented")
                }
    
            default:
                fatalError("not implemented")
            }
            
           
            
            if toVisible {
                let view = self.viewNecessary(at: item.index)
                if let view = view, view.visibleRect.height == item.height {
                   // if animate {
                        view.focusAnimation()
                   // }
                    return
                }
            }
            if clipView.bounds.minY != rowRect.minY {
                
                var applied = false
                let scrollListener = TableScrollListener({ [weak self, weak item] position in
                    if let item = item, !applied, let view = self?.viewNecessary(at: item.index), view.visibleRect.height > 10 {
                        applied = true
                        view.focusAnimation()
                    }
                })
                
                addScroll(listener: scrollListener)
                
                clipView.scroll(to: NSMakePoint(0, round(min(max(rowRect.minY,0), documentSize.height - height) + inset.top)), animated:animate, completion:{ [weak self] _ in
                    
                    if let strongSelf = self {
                        strongSelf.reflectScrolledClipView(strongSelf.clipView)
                    }
                    
                    if !applied {
                        applied = true
                        if let view = self?.viewNecessary(at: item.index) {
                            applied = true
                            view.focusAnimation()
                        }
                    }
                    
                    
                    self?.removeScroll(listener: scrollListener)
                })
                
                
                
            } else {
                viewNecessary(at: item.index)?.focusAnimation()
            }
            
            
            
        } 
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        let visible = visibleItems()
        super.setFrameSize(newSize)
        
        if let visible = visible.last, !tableView.isFlipped {
            if let keys = layer?.animationKeys(), keys.isEmpty {
                if let item = self.item(stableId: visible.0.stableId) {
                    let nrect = rectOf(item: item)
                    
                    let y:CGFloat = nrect.minY - (frame.height - visible.1) + nrect.height
                    
                    self.contentView.bounds = NSMakeRect(0, y, 0, clipView.bounds.height)
                    reflectScrolledClipView(clipView)
                }
            }
            
        } else {
            //TODO
        }
    }
    
    public func setScrollHandler(_ handler: @escaping (_ scrollPosition:ScrollPosition) ->Void) -> Void {
        
        scrollHandler = handler
        
    }
    
    override open func scrollWheel(with event: NSEvent) {
        super.scrollWheel(with: event)
        if needUpdateVisibleAfterScroll {
            let range = visibleRows()
            for i in range.location ..< range.location + range.length {
                if let view = viewNecessary(at: i) {
                    view.updateMouse()
                }
            }
        }
        
    }
    
    public func enumerateItems(with callback:(TableRowItem)->Bool) {
        for item in list {
            if !callback(item) {
                break
            }
        }
    }
    
    public func enumerateViews(with callback:(TableRowView)->Bool) {
        for index in 0 ..< list.count {
            if let view = viewNecessary(at: index) {
                if !callback(view) {
                    break
                }
            }
        }
    }
    
    public func enumerateVisibleViews(with callback:(TableRowView)->Void) {
        let visibleRows = self.visibleRows()
        for index in visibleRows.location ..< visibleRows.location + visibleRows.length {
            if let view = viewNecessary(at: index) {
                callback(view)
            }
        }
    }
    
    public func performScrollEvent() -> Void {
        self.updateScroll()
        NotificationCenter.default.post(name: NSNotification.Name.NSViewBoundsDidChange, object: self.contentView)
    }
    
    deinit {
        mergeDisposable.dispose()
    }
    
    
    
}
