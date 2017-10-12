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
    public let animateVisibleOnly: Bool
    public init(deleted:[Int], inserted:[(Int,T)], updated:[(Int,T)], animateVisibleOnly: Bool = true) {
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
        self.animateVisibleOnly = animateVisibleOnly
    }
    
    public var isEmpty:Bool {
        return inserted.isEmpty && updated.isEmpty && deleted.isEmpty
    }
    
    public var description: String {
        return "inserted: \(inserted.count), updated:\(updated.count), deleted:\(deleted.count)"
    }
}


public class TableUpdateTransition : UpdateTransition<TableRowItem> {
    public let state:TableScrollState
    public let animated:Bool
    public let grouping:Bool
    
    public init(deleted:[Int], inserted:[(Int,TableRowItem)], updated:[(Int,TableRowItem)], animated:Bool = false, state:TableScrollState = .none(nil), grouping:Bool = true, animateVisibleOnly: Bool = true) {
        self.animated = animated
        self.state = state
        self.grouping = grouping
        super.init(deleted: deleted, inserted: inserted, updated: updated, animateVisibleOnly: animateVisibleOnly)
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
    case top(id: AnyHashable, animated: Bool, focus: Bool, inset: CGFloat); // stableId, animated, focus, inset
    case bottom(id: AnyHashable, animated: Bool, focus: Bool, inset: CGFloat); //  stableId, animated, focus, inset
    case center(id: AnyHashable, animated: Bool, focus: Bool, inset: CGFloat); //  stableId, animated, focus, inset
    case saveVisible(TableSavingSide)
    case none(TableAnimationInterface?);
    case down(Bool);
    case up(Bool);
}

public extension TableScrollState {
    public func swap(to stableId:AnyHashable) -> TableScrollState {
        switch self {
        case let .top(_, animated, focus, inset):
            return .top(id: stableId, animated: animated, focus: focus, inset: inset)
        case let .bottom(_, animated, focus, inset):
            return .bottom(id: stableId, animated: animated, focus: focus, inset: inset)
        case let .center(_, animated, focus, inset):
            return .center(id: stableId, animated: animated, focus: focus, inset: inset)
        default:
            return self
        }
    }
    
    public var animated: Bool {
        switch self {
        case let .top(_, animated, _, _):
            return animated
        case let .bottom(_, animated, _, _):
            return animated
        case let .center(_, animated, _, _):
            return animated
        case .down(let animated):
            return animated
        case .up(let animated):
            return animated
        default:
            return false
        }
    }
}

public func ==(lhs:TableScrollState, rhs:TableScrollState) -> Bool {
    switch lhs {
    case let .top(stableId, animated, focus, inset):
        if case .top(stableId, animated, focus, inset) = rhs {
            return true
        } else {
            return false
        }
    case let .bottom(stableId, animated, focus, inset):
        if case .bottom(stableId, animated, focus, inset) = rhs {
            return true
        } else {
            return false
        }
    case let .center(stableId, animated, focus, inset):
        if case .center(stableId, animated, focus, inset) = rhs {
            return true
        } else {
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

//    override public func setNeedsDisplay(_ invalidRect: NSRect) {
//        
//    }
    
    override func addSubview(_ view: NSView) {
        super.addSubview(view)
    }
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(presentation.colors.background.cgColor)
        ctx.fill(self.bounds)
        
        if let border = border {
            
            ctx.setFillColor(presentation.colors.border.cgColor)
            
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
    fileprivate let dispatchWhenVisibleRangeUpdated: Bool
    fileprivate var first: Bool = true
    public init(dispatchWhenVisibleRangeUpdated: Bool = true, _ handler:@escaping(ScrollPosition)->Void) {
        self.dispatchWhenVisibleRangeUpdated = dispatchWhenVisibleRangeUpdated
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
    
    open override var backgroundColor: NSColor {
        didSet {
            documentView?.background = backgroundColor
            contentView.background = backgroundColor
            self.clipView.backgroundColor = backgroundColor
            self.clipView.needsDisplay = true
            documentView?.needsDisplay = true
        }
    }
    
    public func setIsFlipped(_ flipped: Bool)  {
        self.tableView.flip = flipped
    }
    
    public required init(frame frameRect: NSRect, isFlipped:Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {

        let table = TGFlipableTableView(frame:frameRect)
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
        self.autoresizingMask = [.width, .height]
        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.sdelegate = self
        self.tableView.allowsColumnReordering = true
        self.tableView.headerView = nil;
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "column"))
        tableColumn.width = frame.width
        self.tableView.addTableColumn(tableColumn)

        
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
            
            NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: nil, using: { [weak self] notification  in
                if let strongSelf = self {
                    
                    let reqCount = strongSelf.count / 6
                    
                    strongSelf.updateStickAfterScroll(false)
                    
                    let scroll = strongSelf.scrollPosition(strongSelf.visibleRows())
                    
                    if (!strongSelf.updating && !strongSelf.clipView.isAnimateScrolling) {
                        
                       let range = scroll.current.visibleRows
                        
                        if(scroll.current.direction != strongSelf.previousScroll?.direction && scroll.current.rect != strongSelf.previousScroll?.rect) {
                            
                            switch(scroll.current.direction) {
                            case .top:
                                if(range.location  <= reqCount) {
                                    strongSelf.scrollHandler(scroll.current)
                                    strongSelf.previousScroll = scroll.current

                                }
                            case .bottom:
                                if(strongSelf.count - (range.location + range.length) <= reqCount) {
                                    strongSelf.scrollHandler(scroll.current)
                                    strongSelf.previousScroll = scroll.current

                                }
                            case .none:
                                strongSelf.scrollHandler(scroll.current)
                                strongSelf.previousScroll = scroll.current

                            }
                        }
 
                    }
                    for listener in strongSelf.scrollListeners {
                        if !listener.dispatchWhenVisibleRangeUpdated || listener.first || !NSEqualRanges(scroll.current.visibleRows, scroll.previous.visibleRows) {
                            listener.handler(scroll.current)
                            listener.first = false
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
    private var firstTime: Bool = false
    public func set(stickClass:AnyClass?, visible: Bool = true, handler:@escaping(TableStickItem?)->Void) {
        self.stickClass = stickClass
        self.stickHandler = handler
        self.firstTime = true
        if let stickClass = stickClass as? TableStickItem.Type {
            if stickView == nil {
                let stickItem:TableStickItem = stickClass.init(frame.size)
                
                self.stickItem = stickItem
                if visible {
                    let vz = stickItem.viewClass() as! TableStickView.Type
                    stickView = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), stickItem.height))
                    stickView!.header = true
                    stickView!.set(item: stickItem, animated: false)
                    tableView.addSubview(stickView!)
                }
            }
            
            updateStickAfterScroll(false)
            
        } else {
            stickView?.removeFromSuperview()
            stickView = nil
            stickItem = nil
        }
        
    }
    
    func optionalItem(at:Int) -> TableRowItem? {
        return at < count && at >= 0 ? self.item(at: at) : nil
    }
    
    private var needsLayouItemsOnNextTransition:Bool = false
   
    public func layouItemsOnNextTransition() {
        needsLayouItemsOnNextTransition = true
    }
    
    public func layoutItems() {

        let visibleItems = self.visibleItems()
        
        beginTableUpdates()
        enumerateItems { item in
            _ = item.makeSize(frame.width, oldWidth: item.width)
            reloadData(row: item.index, animated: false)
            NSAnimationContext.current.duration =  0.0
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: item.index))
            return true
        }
        endTableUpdates()
        
        saveScrollState(visibleItems)
        
        needsLayouItemsOnNextTransition = false
    }
    
    private func saveScrollState(_ visibleItems: [(TableRowItem,CGFloat,CGFloat)]) -> Void {
        if !visibleItems.isEmpty, clipView.bounds.minY > 0 {
            var nrect:NSRect = NSZeroRect
            
            let strideTo:StrideTo<Int> = stride(from: visibleItems.count - 1, to: -1, by: -1)
            
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
                    if !tableView.isFlipped {
                        y = nrect.minY - (frame.height - visible.1) + nrect.height
                    } else {
                        y = nrect.minY - visible.1
                    }
                    
                    //clipView.scroll(to: NSMakePoint(0, y + frame.minY), animated: false)
                     self.contentView.bounds = NSMakeRect(0, y, 0, clipView.bounds.height)
                    reflectScrolledClipView(clipView)
                    break
                }
            }
        }
    }
    
    private let stickTimeoutDisposable = MetaDisposable()
    
    public func updateStickAfterScroll(_ animated: Bool) -> Void {
        let range = self.visibleRows()
        
        if let stickClass = stickClass {
            if documentSize.height > frame.height {
                var index:Int = range.location + range.length - 1
                
                let flipped = tableView.isFlipped
                
                let scrollInset = self.documentOffset.y + (flipped ? 0 : frame.height)
                var item:TableRowItem? = optionalItem(at: index)
                
                while let s = item, !s.isKind(of: stickClass) {
                    index += 1
                    item = self.optionalItem(at: index)
                }
                
                if item == nil {
                    index = range.location + range.length
                    while item == nil && index < count {
                        if let s = self.optionalItem(at: index), s.isKind(of: stickClass) {
                            item = s
                        }
                        index += 1
                    }
                }
                
                if let item = item as? TableStickItem {
                    var currentStick:TableStickItem?
                    
                    for index in stride(from: item.index - 1, to: -1, by: -1) {
                        let item = self.optionalItem(at: index)
                        if let item = item, item.isKind(of: stickClass) {
                            currentStick = item as? TableStickItem
                            break
                        }
                    }
                    
                    if stickView?.item != item {
                        stickView?.set(item: item, animated: tableView.subviews.last == stickView)
                    }
                    
                    if let item = stickItem {
                        (viewNecessary(at: item.index) as? TableStickView)?.updateIsVisible(!firstTime, animated: false)
                        
                        
                    }

                    stickItem = currentStick ?? item
                    
                    (viewNecessary(at: item.index) as? TableStickView)?.updateIsVisible(false, animated: false)
                    
                    if let stickView = stickView {
                        if tableView.subviews.last != stickView {
                            stickView.removeFromSuperview()
                            tableView.addSubview(stickView)
                        }
                    }
                    
                    stickView?.setFrameSize(tableView.frame.width, item.height)
                    let itemRect:NSRect = tableView.rect(ofRow: item.index)

                    if let item = stickItem, item.isKind(of: stickClass), let stickView = stickView {
                        let rect:NSRect = tableView.rect(ofRow: item.index)
                        let dif:CGFloat
                        if currentStick != nil {
                            dif = min(scrollInset - rect.maxY, item.height)
                        } else {
                            dif = item.height
                        }
                        let yTopOffset:CGFloat = min(max(scrollInset - dif, 0), documentSize.height - item.height)
                        if stickView.frame.minY != yTopOffset {
                            stickView.isHidden = firstTime
                            if !animated || stickView.layer?.opacity != 0 {
                                stickView.change(opacity: firstTime ? 0 : 1, animated: !firstTime)
                                firstTime = false
                            }
                        }
                        stickView.change(pos: NSMakePoint(0, yTopOffset), animated: animated)
                        stickView.header = fabs(dif) <= item.height
                        stickTimeoutDisposable.set((Signal<Void, Void>.single(Void()) |> delay(2.0, queue: Queue.mainQueue())).start(next: { [weak stickView, weak item] in
                            if let item = item, abs(itemRect.minY - yTopOffset) > item.height, let stickView = stickView {
                                stickView.change(opacity: 0.0, completion: { [weak stickView] completed in
                                    if completed {
                                        stickView?.isHidden = true
                                    }
                                })
                            }
                            
                        }))
                        
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
        updateScroll()
    }
    
    public func notifyScrollHandlers() -> Void {
        let scroll = scrollPosition(visibleRows()).current
        for listener in scrollListeners {
            listener.handler(scroll)
        }
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
    
    public func insert(item:TableRowItem, at:Int = 0, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Bool {
        
        assert(self.item(stableId:item.stableId) == nil, "inserting existing row inTable: \(self.item(stableId:item.stableId)!.className), new: \(item.className)")
        self.listhash[item.stableId] = item;
        self.list.insert(item, at: min(at, list.count));
        item.table = self;
        
        let animation = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current.duration = animation != .none ? 0.2 : 0.0
        
        if(redraw) {
            self.tableView.insertRows(at: IndexSet(integer: at), withAnimation: animation)
        }
        
        return true;
        
    }
    
    public func addItem(item:TableRowItem, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Bool {
        return self.insert(item: item, at: self.count, redraw: redraw, animation:animation)
    }
    
    public func insert(items:[TableRowItem], at:Int = 0, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        
        
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
            NSAnimationContext.current.duration = 0
        }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
    }
    
    
    
    public func reloadData(row:Int, animated:Bool = false) -> Void {
        if let view = self.viewNecessary(at: row) {
            let item = self.item(at: row)
            if view.isKind(of: item.viewClass()) {
                if let viewItem = view.item {
                    if viewItem.height != item.height {
                        NSAnimationContext.current.duration = animated ? 0.2 : 0.0
                        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                    }
                } else {
                    NSAnimationContext.current.duration = animated ? 0.2 : 0.0
                    tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
                
                view.set(item: item, animated: animated)
                view.needsDisplay = true
            } else {
                self.tableView.removeRows(at: IndexSet(integer: row), withAnimation: !animated ? .none : .effectFade)
                self.tableView.insertRows(at: IndexSet(integer: row), withAnimation: !animated ? .none :  .effectFade)
            }
        } else {
            NSAnimationContext.current.duration = 0.0
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        }
        //self.moveItem(from: row, to: row)
    }
    
    public func moveItem(from:Int, to:Int, changeItem:TableRowItem? = nil, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        
        
        var item:TableRowItem = self.item(at:from);
        let animation: NSTableView.AnimationOptions = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current.duration = animation != .none ? NSAnimationContext.current.duration : 0.0
       
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
        updateScroll(visibleRows())
        self.previousScroll = nil
        CATransaction.begin()
    }
    
    public func endUpdates() -> Void {
        updating = false
        updateScroll(visibleRows())
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
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        if at < count {
            let item = self.item(at: at)
            let animation: NSTableView.AnimationOptions = animation != .none ? item.animatable ? animation : .none : .none
            NSAnimationContext.current.duration = animation == .none ? 0.0 : 0.2
            
            self.list.remove(at: at);
            self.listhash.removeValue(forKey: item.stableId)
            
            if(redraw) {
                self.tableView.removeRows(at: IndexSet(integer:at), withAnimation: animation != .none ? .effectFade : .none)
            }
        }
    }
    
    public func remove(range:Range<Int>, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        
        for i in range.lowerBound ..< range.upperBound {
            remove(at: i, redraw: false)
        }
        
        if(redraw) {
            self.tableView.removeRows(at: IndexSet(integersIn:range), withAnimation:  animation != .none ? .effectFade : .none)
        }
    }
    

    
    public func removeAll(redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        let count:Int = self.count;
        self.list.removeAll()
        self.listhash.removeAll()
        
        if(redraw) {
            
            self.tableView.removeRows(at: IndexSet(integersIn: 0 ..< count), withAnimation:  animation != .none ? .effectFade : .none)
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
            self.scroll(to: .top(id: hash, animated: animated, focus: false, inset: 0), inset: NSEdgeInsets(), true)
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
            self.scroll(to: .bottom(id: hash, animated: animated, focus: false, inset: 0), inset: NSEdgeInsets(), true)
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
        
        var view = self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: self.tableView)
        if(view == nil) {
            let vz = item.viewClass() as! TableRowView.Type
            
            view = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), item.height))
            
            view?.identifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
            
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
                    list.append((item,top,bottom))
                } else {
                    let top = rect.minY - documentOffset.y
                    let bottom = frame.height - (rect.minY - documentOffset.y) - rect.height
                    list.append((item,top,bottom))
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
        let visibleRange = self.visibleRows()
        if transition.grouping && !transition.isEmpty {
            self.tableView.beginUpdates()
        }
        
        var inserted:[TableRowItem] = []
        var removed:[TableRowItem] = []

        for rdx in transition.deleted.reversed() {
            let effect:NSTableView.AnimationOptions
            if case let .none(interface) = transition.state, interface != nil {
                effect = (visibleRange.indexIn(rdx) || !transition.animateVisibleOnly) ? .effectFade : .none
            } else {
                effect = transition.animated && (visibleRange.indexIn(rdx) || !transition.animateVisibleOnly) ? .effectFade : .none
            }
            if rdx < visibleRange.location {
                removed.append(item(at: rdx))
            }
            self.remove(at: rdx, redraw: true, animation:effect)
        }
        
        NSAnimationContext.current.duration = transition.animated ? 0.2 : 0.0
        

        for (idx,item) in transition.inserted {
            let effect:NSTableView.AnimationOptions = transition.animated ? .effectFade : .none
            _ = self.insert(item: item, at:idx, redraw: true, animation: effect)
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
        let state: TableScrollState
        
        if case .none = transition.state {
            let isSomeOfItemVisible = !inserted.filter({$0.isVisible}).isEmpty || !removed.filter({$0.isVisible}).isEmpty
            if isSomeOfItemVisible {
                state = transition.state
            } else {
                state = .saveVisible(.upper)
            }
        } else {
            state = transition.state
        }
        
        //reflectScrolledClipView(clipView)
        switch state {
        case let .none(animation):
            // print("scroll do nothing")
            animation?.animate(table:self, added: inserted, removed:removed)
            
        case .bottom, .top, .center:
            self.scroll(to: transition.state)
        case .up(_), .down(_):
            self.scroll(to: transition.state)
        case let .saveVisible(side):
            
//            if transition.isEmpty {
//                break
//            }

            var nrect:NSRect = NSZeroRect
            
            let strideTo:StrideTo<Int>
            
            if !tableView.isFlipped {
                switch side {
                case .lower:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .upper:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1) //stride(from: 0, to: visibleItems.count, by: 1)
                }
            } else {
                switch side {
                case .upper:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .lower:
                    strideTo = stride(from: 0, to: visibleItems.count, by: 1)
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
    
    public override func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        
        
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
                
                contentView.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, contentView.bounds.minY, size.width, size.height), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, completion: completion)
                CATransaction.commit()
            } else {
                super.change(size: size, animated: animated, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
                return
            }
        }
        self.setFrameSize(size)
        updateStickAfterScroll(animated)
    }
    
    
    
    public func scroll(to state:TableScrollState, inset:NSEdgeInsets = NSEdgeInsets(), _ toVisible:Bool = false) {
       // if let index = self.index(of: item) {
        
        var rowRect:NSRect = bounds
        
        var item:TableRowItem?
        var animate:Bool = false
        var focus: Bool = false
        var relativeInset: CGFloat = 0
        switch state {
        case let .center(stableId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
        case let .bottom(stableId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
        case let .top(stableId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
        case let .down(_animate):
            animate = _animate
            if !tableView.isFlipped {
                rowRect.origin = NSZeroPoint
            } else {
                rowRect.origin = NSMakePoint(0, max(0,documentSize.height - frame.height))
            }
        case let .up(_animate):
            animate = _animate
            if !tableView.isFlipped {
                rowRect.origin = NSMakePoint(0, max(documentSize.height,frame.height))
            } else {
               rowRect.origin = NSZeroPoint
            }
        default:
            fatalError("for scroll to item, you can use only .top, center, .bottom enumeration")
        }
        
        let bottomInset = self.bottomInset != 0 ? (self.bottomInset) : 0
        let height:CGFloat = self is HorizontalTableView ? frame.width : frame.height

        if let item = item {
            rowRect = self.rectOf(item: item)
            
            switch state {
            case .bottom:
                if tableView.isFlipped {
                    rowRect.origin.y -= (height - rowRect.height) - bottomInset
                }
            case .top:
               // break
                if !tableView.isFlipped {
                    rowRect.origin.y -= (height - rowRect.height) - bottomInset
                }
            case .center:
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
                    if focus {
                        view.focusAnimation()
                    }
                    return
                }
            }
        }
        rowRect.origin.y = round(min(max(rowRect.minY + relativeInset,0), documentSize.height - height) + inset.top)
        if clipView.bounds.minY != rowRect.minY {
            
            var applied = false
            let scrollListener = TableScrollListener({ [weak self, weak item] position in
                if let item = item, !applied, let view = self?.viewNecessary(at: item.index), view.visibleRect.height > 10 {
                    applied = true
                    if focus {
                        view.focusAnimation()
                    }
                }
            })
            
            addScroll(listener: scrollListener)
            
            let bounds = NSMakeRect(0, rowRect.minY, clipView.bounds.width, clipView.bounds.height)
            
            
            let getEdgeInset:()->CGFloat = {
                if bounds.minY > self.clipView.bounds.minY {
                    return height
                } else {
                    return -height
                }
            }
            
            if abs(bounds.minY - clipView.bounds.minY) < height {
                clipView.scroll(to: bounds.origin, animated: animate, completion: { [weak self] _ in
                    self?.removeScroll(listener: scrollListener)
                })
            } else {
                let edgeRect:NSRect = NSMakeRect(clipView.bounds.minX, bounds.minY - getEdgeInset() - frame.minY, clipView.bounds.width, clipView.bounds.height)
                clipView._changeBounds(from: edgeRect, to: bounds, animated: animate, duration: 0.4, timingFunction: kCAMediaTimingFunctionSpring, completion: { [weak self] completed in
                    self?.removeScroll(listener: scrollListener)
                })
            }
        } else {
            if let item = item, focus {
                viewNecessary(at: item.index)?.focusAnimation()
            }
        }

    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        let visible = visibleItems()
        let oldWidth = frame.width
        super.setFrameSize(newSize)
        //updateStickAfterScroll(false)
        if oldWidth != newSize.width {
            saveScrollState(visible)
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
    
    public func enumerateVisibleItems(reversed: Bool = false, with callback:(TableRowItem)->Bool) {
        let visible = visibleRows()
        
        if reversed {
            for i in stride(from: visible.location + visible.length - 1, to: visible.location - 1, by: -1) {
                if !callback(list[i]) {
                    break
                }
            }
        } else {
            for i in visible.location ..< visible.location + visible.length  {
                if !callback(list[i]) {
                    break
                }
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
        self.updateScroll(visibleRows())
        NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self.contentView)
    }
    
    deinit {
        mergeDisposable.dispose()
        stickTimeoutDisposable.dispose()
    }
    
    
    
}
