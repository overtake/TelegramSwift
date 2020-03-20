//
//  TableView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit
import AVFoundation

public enum TableSeparator {
    case bottom;
    case top;
    case right;
    case left;
    case none;
}

struct RevealAction {
    
    
}

public class RowAnimateView: View {
    public var stableId:AnyHashable?
}

public final class RevealTableItemController : ViewController  {
    public let item: TableRowItem
    public init(item: TableRowItem)  {
        self.item = item
        super.init()
    }
}

public protocol RevealTableView {
    var additionalRevealDelta: CGFloat { get }
    var containerX: CGFloat { get }
    var rightRevealWidth: CGFloat { get }
    var leftRevealWidth: CGFloat { get }
    var endRevealState:SwipeDirection? { get set }
    
    var width: CGFloat { get }
    
    func initRevealState()
    
    func moveReveal(delta: CGFloat)
    func completeReveal(direction: SwipeDirection)
}

public enum TableBackgroundMode {
    case plain
    case color(color: NSColor)
    case gradient(top: NSColor, bottom: NSColor, rotation: Int32?)
    case background(image: NSImage)
    case tiled(image: NSImage)
    
    public var hasWallpapaer: Bool {
        switch self {
        case .plain:
            return false
        case let .color(color):
            return color != presentation.colors.chatBackground
        default:
            return true
        }
    }
}

public class TableResortController {
    fileprivate let startTimeout: Double
    fileprivate var resortRow: Int?
    internal fileprivate(set) var resortView: TableRowView? {
        didSet {
            if resortView == nil {
                oldValue?.isResorting = false
            } else {
                resortView?.isResorting = true
            }
        }
    }
    fileprivate var inResorting: Bool = false
    fileprivate var startLocation: NSPoint = NSZeroPoint
    fileprivate var startRowLocation: NSPoint = NSZeroPoint
    
    fileprivate var currentHoleIndex: Int?
    fileprivate var prevHoleIndex: Int?
    
    public var resortRange: NSRange
    fileprivate let start:(Int)->Void
    fileprivate let resort:(Int)->Void
    fileprivate let complete:(Int, Int)->Void
    fileprivate let updateItems:(TableRowView?, [TableRowItem])->Void
    public init(resortRange: NSRange, startTimeout: Double = 0.3, start:@escaping(Int)->Void, resort:@escaping(Int)->Void, complete:@escaping(Int, Int)->Void, updateItems:@escaping(TableRowView?, [TableRowItem])->Void = { _, _ in }) {
        self.resortRange = resortRange
        self.startTimeout = startTimeout
        self.start = start
        self.resort = resort
        self.complete = complete
        self.updateItems = updateItems
    }
    
    func clear() {
        resortView = nil
        resortRow = nil
        startLocation = NSZeroPoint
        startRowLocation = NSZeroPoint
    }
    
    var isResorting: Bool {
        return resortView != nil
    }
    
    func canResort(_ row: Int) -> Bool {
        return resortRange.indexIn(row)
    }
}



public class UpdateTransition<T> {
    public let inserted:[(Int,T)]
    public let updated:[(Int,T)]
    public let deleted:[Int]
    public let animateVisibleOnly: Bool
    public init(deleted:[Int], inserted:[(Int,T)], updated:[(Int,T)], animateVisibleOnly: Bool = true) {
        

  
//        for d_idx in stride(from: deleted.count - 1, to: -1, by: -1) {
//            in_loop: for i_idx in stride(from: inserted.count - 1, to: -1, by: -1) {
//                if deleted[d_idx] == inserted[i_idx].0 {
//                    if !updated.isEmpty {
//                        u_loop: for u_udx in 0 ..< updated.count {
//                            assert(updated[u_udx].0 != inserted[i_idx].0)
//                            if updated[u_udx].0 > inserted[i_idx].0 {
//                                updated.insert(inserted[i_idx], at: u_udx)
//                                break u_loop
//                            }
//                        }
//                    } else {
//                        updated.append(inserted[i_idx])
//                    }
//
//                    deleted.remove(at: d_idx)
//                    inserted.remove(at: i_idx)
//                    break in_loop
//                }
//            }
//        }
        
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
public struct TableSearchVisibleData {
    let cancelImage: CGImage?
    let cancel:()->Void
    let updateState: (SearchState)->Void
    public init(cancelImage: CGImage? = nil, cancel: @escaping()->Void, updateState: @escaping(SearchState)->Void) {
        self.cancelImage = cancelImage
        self.cancel = cancel
        self.updateState = updateState
    }
}

public enum TableSearchViewState : Equatable {
    case none
    case visible(TableSearchVisibleData)
    
    public static func ==(lhs: TableSearchViewState, rhs: TableSearchViewState) -> Bool {
        switch lhs {
        case .none:
            if case .none = rhs {
                return true
            } else {
                return false
            }
        case .visible:
            if case .visible = rhs {
                return true
            } else {
                return false
            }
        }
    }
}

public class TableUpdateTransition : UpdateTransition<TableRowItem> {
    public let state:TableScrollState
    public let animated:Bool
    public let grouping:Bool
    public let searchState: TableSearchViewState?
    public init(deleted:[Int], inserted:[(Int,TableRowItem)], updated:[(Int,TableRowItem)], animated:Bool = false, state:TableScrollState = .none(nil), grouping:Bool = true, animateVisibleOnly: Bool = true, searchState: TableSearchViewState? = nil) {
        self.animated = animated
        self.state = state
        self.grouping = grouping
        self.searchState = searchState
        super.init(deleted: deleted, inserted: inserted, updated: updated, animateVisibleOnly: animateVisibleOnly)
    }
    public override var description: String {
        return "inserted: \(inserted.count), updated:\(updated.count), deleted:\(deleted.count), state: \(state), animated: \(animated)"
    }
    deinit {
        var bp:Int = 0
        bp += 1
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
    func selectionWillChange(row:Int, item:TableRowItem, byClick:Bool) -> Bool;
    func isSelectable(row:Int, item:TableRowItem) -> Bool;
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable?
}

extension TableViewDelegate {
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
}

public enum TableSavingSide : Equatable {
    case lower
    case upper
    case aroundIndex(AnyHashable)
}

public func ==(lhs: TableSavingSide, rhs: TableSavingSide) -> Bool {
    switch lhs {
    case .lower:
        if case .lower = rhs {
            return true
        } else {
            return false
        }
    case .upper:
        if case .upper = rhs {
            return true
        } else {
            return false
        }
    case let .aroundIndex(id):
        if case .aroundIndex(id) = rhs {
            return true
        } else {
            return false
        }
    }
}

public struct TableScrollFocus : Equatable {
    public static func == (lhs: TableScrollFocus, rhs: TableScrollFocus) -> Bool {
        return lhs.focus == rhs.focus
    }
    let focus:Bool
    let action:((NSView)->Void)?
    public init(focus: Bool, action: ((NSView)->Void)? = nil) {
        self.focus = focus
        self.action = action
    }
    
    
}

public enum TableScrollState :Equatable {
    case top(id: AnyHashable, innerId: AnyHashable?, animated: Bool, focus: TableScrollFocus, inset: CGFloat); // stableId, animated, focus, inset
    case bottom(id: AnyHashable, innerId: AnyHashable?, animated: Bool, focus: TableScrollFocus, inset: CGFloat); //  stableId, animated, focus, inset
    case center(id: AnyHashable, innerId: AnyHashable?, animated: Bool, focus: TableScrollFocus, inset: CGFloat); //  stableId, animated, focus, inset
    case saveVisible(TableSavingSide)
    case none(TableAnimationInterface?);
    case down(Bool);
    case up(Bool);
    case upOffset(Bool, CGFloat);
}

public extension TableScrollState {
    
    func swap(to stableId:AnyHashable, innerId: AnyHashable? = nil) -> TableScrollState {
        switch self {
        case let .top(_, _, animated, focus, inset):
            return .top(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: inset)
        case let .bottom(_, _, animated, focus, inset):
            return .bottom(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: inset)
        case let .center(_, _, animated, focus, inset):
            return .center(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: inset)
        default:
            return self
        }
    }
    
    var animated: Bool {
        switch self {
        case let .top(_, _, animated, _, _):
            return animated
        case let .bottom(_, _, animated, _, _):
            return animated
        case let .center(_, _, animated, _, _):
            return animated
        case .down(let animated):
            return animated
        case .up(let animated):
            return animated
        case let .upOffset(animated, _):
            return animated
        default:
            return false
        }
    }
}


protocol SelectDelegate : class {
    func selectRow(index:Int) -> Void;
}

private final class TableSearchView : View {
    let searchView = SearchView(frame: NSZeroRect)
    private var cancelButton:ImageButton?
    required init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addSubview(searchView)
        background = presentation.colors.background
        border = [.Bottom]
        searchView.frame = NSMakeRect(10, 10, frame.width - 20, frame.height - 20)
    }
    
    func applySearchResponder() {
        // _ = window?.makeFirstResponder(searchView.input)
        searchView.layout()
        _ = window?.makeFirstResponder(searchView.input)
        searchView.change(state: .Focus, false)
    }
    
    func updateDatas(_ datas: TableSearchVisibleData) {
        if let cancelImage = datas.cancelImage {
            if self.cancelButton == nil {
                self.cancelButton = ImageButton()
                self.addSubview(cancelButton!)
            }
            cancelButton!.removeAllHandlers()
            cancelButton!.set(image: cancelImage, for: .Normal)
            cancelButton!.set(handler: { _ in
                datas.cancel()
            }, for: .Click)
            _ = cancelButton!.sizeToFit()
        } else {
            cancelButton?.removeFromSuperview()
            cancelButton = nil
        }
       
        
        searchView.searchInteractions = SearchInteractions({ state, _ in
            datas.updateState(state)
        }, { state in
            datas.updateState(state)
        })
        
        needsLayout = true
    }
    
    override func layout() {
        super.layout()
        if let cancelButton = self.cancelButton {
            cancelButton.centerY(x: frame.width - 10 - cancelButton.frame.width)
            searchView.frame = NSMakeRect(10, 10, frame.width - cancelButton.frame.width - 30, frame.height - 20)
        } else {
            searchView.frame = NSMakeRect(10, 10, frame.width - 20, frame.height - 20)
        }
    }
    
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class TGFlipableTableView : NSTableView, CALayerDelegate {
    
    var bottomInset:CGFloat = 0
    private let longDisposable = MetaDisposable()
    public var flip:Bool = true
    
    public weak var sdelegate:SelectDelegate?
    weak var table:TableView?
    var border:BorderType?
    
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        backgroundColor = .clear
        self.autoresizesSubviews = false
     //  canDrawSubviewsIntoLayer = true
        usesAlternatingRowBackgroundColors = false
        layerContentsRedrawPolicy = .never
    }
    
    override func becomeFirstResponder() -> Bool {
        return false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    override var isFlipped: Bool {
        return flip
    }
    
    override func draw(_ dirtyRect: NSRect) {
       
    }
    override var isOpaque: Bool {
        return false
    }

    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point)
    }
    
    override func addSubview(_ view: NSView) {
        super.addSubview(view)
    }
    
    func draw(_ layer: CALayer, in ctx: CGContext) {

        
       
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

    private var beforeRange: NSRange = NSMakeRange(NSNotFound, 0)
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            let point = self.convert(event.locationInWindow, from: nil)
            let beforeRange = self.rows(in: NSMakeRect(point.x, point.y, 1, 1))
            if beforeRange.length > 0 {
                self.beforeRange = beforeRange
                if let resortController = table?.resortController, beforeRange.length > 0 {
                    if resortController.resortRange.indexIn(beforeRange.location) {
                        longDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(resortController.startTimeout, queue: Queue.mainQueue())).start(next: { [weak self] in
                            let currentEvent = NSApp.currentEvent
                            guard let `self` = self, let ev = currentEvent, ev.type == .leftMouseDown || ev.type == .leftMouseDragged || ev.type == .pressure else {return}
                            let point = self.convert(ev.locationInWindow, from: nil)
                            let afterRange = self.rows(in: NSMakeRect(point.x, point.y, 1, 1))
                            if afterRange == beforeRange {
                                self.table?.startResorting()
                            }
                        }))
                    } else if let table = table, !table.alwaysOpenRowsOnMouseUp {
                        sdelegate?.selectRow(index: beforeRange.location)
                    }
                    
                } else if let table = table, !table.alwaysOpenRowsOnMouseUp {
                    sdelegate?.selectRow(index: beforeRange.location)
                }
            }
        }
    }
    
    
    deinit {
        longDisposable.dispose()
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        let oldWidth: CGFloat = frame.width
        let oldHeight: CGFloat = frame.height

        if newSize.width > 0 || newSize.height > 0 {
            super.setFrameSize(newSize)
            
            if oldWidth != frame.width {
                if let table = table {
                    table.layoutIfNeeded(with: table.visibleRows(), oldWidth: oldWidth)
                }
            } else if oldHeight != frame.height {
                table?.reloadHeightItems()
            }
        }
    }
    
    
    
    var liveWidth:CGFloat = 0
    
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        liveWidth = frame.width
    }
    
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        if liveWidth  != frame.width {
            liveWidth = 0
            table?.layoutItems()
        }
    }
    
    override func layout() {
        super.layout()
    }
    
    
    override func mouseUp(with event: NSEvent) {
        longDisposable.set(nil)
        let point = self.convert(event.locationInWindow, from: nil)
        let range  = self.rows(in: NSMakeRect(point.x, point.y, 1, 1));
        if range.length > 0 {
            if let controller = self.table?.resortController {
                if !controller.resortRange.indexIn(range.location) {
                    if let table = table, table.alwaysOpenRowsOnMouseUp, beforeRange.location == range.location {
                        sdelegate?.selectRow(index: range.location)
                    }
                    return
                }
                if range.length > 0, beforeRange.location == range.location {
                    sdelegate?.selectRow(index: range.location)
                }
            } else if let table = table, table.alwaysOpenRowsOnMouseUp, beforeRange.location == range.location {
                sdelegate?.selectRow(index: range.location)
            }
        }
    }

}

public protocol InteractionContentViewProtocol : class {
    func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView?
    func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable)
    func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView)
    func videoTimebase(for stableId: AnyHashable) -> CMTimebase?
    func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?)

}

public class TableScrollListener : NSObject {
    fileprivate let uniqueId:UInt32 = arc4random()
    public var handler:(ScrollPosition)->Void
    fileprivate let dispatchWhenVisibleRangeUpdated: Bool
    fileprivate var first: Bool = true
    public init(dispatchWhenVisibleRangeUpdated: Bool = true, _ handler:@escaping(ScrollPosition)->Void) {
        self.dispatchWhenVisibleRangeUpdated = dispatchWhenVisibleRangeUpdated
        self.handler = handler
    }
    
}

public struct TableAutohide {
    public private(set) weak var item: TableRowItem?
    let hideUntilOverscroll: Bool
    let hideHandler:(Bool)->Void
    public init(item: TableRowItem?, hideUntilOverscroll: Bool = false, hideHandler:@escaping(Bool)->Void = { _ in }) {
        self.item = item
        self.hideUntilOverscroll = hideUntilOverscroll
        self.hideHandler = hideHandler
    }
}

open class TableView: ScrollView, NSTableViewDelegate,NSTableViewDataSource,SelectDelegate,InteractionContentViewProtocol, AppearanceViewProtocol {
    
    private var searchView: TableSearchView?
    private var rightBorder: View? = nil
    public var separator:TableSeparator = .none
    
    public var getBackgroundColor:()->NSColor = { presentation.colors.background } {
        didSet {
            if super.layer?.backgroundColor != .clear {
                super.layer?.backgroundColor = self.getBackgroundColor().cgColor
            }
            self.needsDisplay = true

        }
    }
    

    var list:[TableRowItem] = [TableRowItem]();
    var tableView:TGFlipableTableView
    weak public var delegate:TableViewDelegate?
    private var trackingArea:NSTrackingArea?
    private var listhash:[AnyHashable:TableRowItem] = [AnyHashable:TableRowItem]();
    
    private let mergePromise:Promise<TableUpdateTransition> = Promise()
    private let mergeDisposable:MetaDisposable = MetaDisposable()
    
    public var resortController: TableResortController? {
        didSet {
            
        }
    }
   
    public var selectedhash:AnyHashable? = nil
    public var highlitedHash:AnyHashable? = nil

    
    private var updating:Bool = false
    
    private var previousScroll:ScrollPosition?
    public var needUpdateVisibleAfterScroll:Bool = false
    private var scrollHandler:(_ scrollPosition:ScrollPosition) ->Void = {_ in}
    
    private var backgroundView: ImageView? 
    
    private var scrollListeners:[TableScrollListener] = []
    
    public var alwaysOpenRowsOnMouseUp: Bool = true
    
    public var autohide: TableAutohide?
    
    public var emptyChecker: (([TableRowItem]) -> Bool)? = nil
    
    
    public var beforeSetupItem:((TableRowView, TableRowItem)->Void)?
    public var afterSetupItem:((TableRowView, TableRowItem)->Void)?
    
    private var nextScrollEventIsAnimated: Bool = false

    public var emptyItem:TableRowItem? {
        didSet {
            emptyItem?.table = self
            updateEmpties()
        }
    }
    private var emptyView:TableRowView?
    
    public func addScroll(listener:TableScrollListener) {
        var found: Bool = false
        for enumerate in scrollListeners {
            if enumerate.uniqueId == listener.uniqueId {
                found = true
                break
            }
        }
        if !found {
            scrollListeners.append(listener)
        }
    }
    
    
    public var bottomInset:CGFloat = 0 {
        didSet {
            tableView.bottomInset = bottomInset
        }
    }
    
    open override func viewDidChangeBackingProperties() {
        
    }
    
    open func updateLocalizationAndTheme(theme: PresentationTheme) {
        if super.layer?.backgroundColor != .clear {
            super.layer?.backgroundColor = self.getBackgroundColor().cgColor
        }
        rightBorder?.backgroundColor = theme.colors.border
        //tableView.background = .clear
      //  super.layer?.backgroundColor = .clear
        self.needsDisplay = true
      //  tableView.needsDisplay = true
      //  clipView.needsDisplay = true
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
    
//    open override func setNeedsDisplay(_ invalidRect: NSRect) {
//
//    }

    open override var isFlipped: Bool {
        return true
    }
    
    public override init(frame frameRect: NSRect) {
        self.tableView = TGFlipableTableView(frame:frameRect)
        self.tableView.wantsLayer = true
        self.tableView.autoresizesSubviews = false
        super.init(frame: frameRect)
        
        updateAfterInitialize(isFlipped:true, drawBorder: false)
    }
    
    public init(frame frameRect: NSRect, isFlipped:Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {
        self.tableView = TGFlipableTableView(frame:frameRect)
        self.tableView.wantsLayer = true
        self.tableView.autoresizesSubviews = false
        super.init(frame: frameRect)
        updateAfterInitialize(isFlipped: isFlipped, drawBorder: drawBorder)
    }

    public convenience init() {
        self.init(frame: NSZeroRect)
    }
    
    public var border:BorderType? {
        didSet {
            self.clipView.border = border
            self.tableView.border = border
            
            if border == [.Right] {
                if rightBorder == nil {
                    rightBorder = View()
                    rightBorder?.backgroundColor = presentation.colors.border
                    addSubview(rightBorder!)
                    needsLayout = true
                }
            } else {
                rightBorder?.removeFromSuperview()
                rightBorder = nil
            }
        }
    }
    
    open override var backgroundColor: NSColor {
        didSet {
//            documentView?.background = backgroundColor
//            contentView.background = backgroundColor
//            self.clipView.backgroundColor = backgroundColor
//            self.clipView.needsDisplay = true
//            documentView?.needsDisplay = true
        }
    }
    
    public func setIsFlipped(_ flipped: Bool)  {
        self.tableView.flip = flipped
    }
    
    public func updateAfterInitialize(isFlipped:Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {

        self.tableView.flip = isFlipped
        
        clipView.copiesOnScroll = true
        
       // self.scrollsDynamically = true
       // self.verticalLineScroll = 0
        //self.verticalScrollElasticity = .none
        self.autoresizesSubviews = false

        self.tableView.table = self
        
        self.bottomInset = bottomInset
        self.tableView.bottomInset = bottomInset
        
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
        self.tableView.allowsColumnReordering = false
        self.tableView.headerView = nil;
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        
        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "column"))
        tableColumn.width = frame.width
        
        self.tableView.addTableColumn(tableColumn)

        
        mergeDisposable.set(mergePromise.get().start(next: { [weak self] (transition) in
            self?.merge(with: transition)
        }))
        
    }
    
    private func findBackgroundControllerView(view: NSView) -> BackgroundView? {
        if let superview = view.superview {
            for subview in superview.subviews {
                if let subview = subview as? BackgroundView {
                    return subview
                } else {
                    if let superview = subview.superview {
                        if let result = findBackgroundControllerView(view: superview) {
                            return result
                        }
                    }
                }
            }
        }
        return nil
    }
    
    private var findBackgroundControllerView: BackgroundView? {
        return self.findBackgroundControllerView(view: self)
    }
    
    open override func layout() {
        super.layout()
        if let emptyView = emptyView, let superview = superview {
            emptyView.frame = findBackgroundControllerView?.bounds ?? bounds
            emptyView.centerX(y: superview.frame.height - emptyView.frame.height)
        }
        if let searchView = searchView {
            searchView.setFrameSize(NSMakeSize(frame.width, searchView.frame.height))
        }
       
        if needsLayouItemsOnNextTransition {
            layoutItems()
        }
        if let rightBorder = rightBorder {
            rightBorder.frame = NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height)
        }
        
        if let stickView = stickView {
            stickView.frame = NSMakeRect(stickView.frame.minX, stickView.frame.minY, frame.width, stickView.frame.height)
        }
    }
    
    
    func layoutIfNeeded(with range:NSRange, oldWidth:CGFloat) {
        for i in range.min ..< range.max {
            let item = self.item(at: i)
            let before = item.heightValue
            let updated = item.makeSize(tableView.frame.width, oldWidth: oldWidth)
            let after = item.heightValue
            if (before != after && updated) || item.instantlyResize {
                reloadData(row: i, animated: false)
                noteHeightOfRow(i, false)
            }
        }
    }
    
    private var liveScrollStartPosition: NSPoint?
    
    public var _scrollWillStartLiveScrolling:(()->Void)?
    public var _scrollDidLiveScrolling:(()->Void)?
    public var _scrollDidEndLiveScrolling:(()->Void)?

    open func scrollWillStartLiveScrolling() {
        liveScrollStartPosition = documentOffset
        _scrollWillStartLiveScrolling?()
    }
    private var liveScrollStack:[CGFloat] = []
    open func scrollDidLiveScrolling() {
        
        liveScrollStack.append(documentOffset.y)
        if documentOffset.y < -10, let liveScrollStartPosition = liveScrollStartPosition, let autohide = self.autohide, let item = autohide.item {
           
            if liveScrollStartPosition.y <= 0 && liveScrollStack.max() ?? 0 <= item.height / 2 {
                if item.isAutohidden {
                    item.unhideItem(animated: true)
                    autohide.hideHandler(false)
                    liveScrollStack.removeAll()
                }
            }
        }
        _scrollDidLiveScrolling?()
    }
    
    
    public var updateScrollPoint:((NSPoint)->NSPoint)? = nil
    
    open override func scroll(_ clipView: NSClipView, to point: NSPoint) {
        var point = point
        if let updateScrollPoint = updateScrollPoint {
            point = updateScrollPoint(point)
        }
        clipView.scroll(to: point)
    }
    
    open func scrollDidChangedBounds() {
        if let autohide = autohide, let item = autohide.item, autohide.hideUntilOverscroll, let _ = liveScrollStartPosition {
            let rect = self.rectOf(item: item)
            
            if !item.isAutohidden, documentOffset.y >= rect.maxY {
                item.hideItem(animated: false, reload: false)
                
                liveScrollStartPosition = nil
                liveScrollStack.removeAll()
                self.merge(with: TableUpdateTransition(deleted: [item.index], inserted: [(item.index, item)], updated: [], animated: false, state: .saveVisible(.upper)))
                
                autohide.hideHandler(true)
            }
        }
    }
    
    open func scrollDidEndLiveScrolling() {
        if let autohide = self.autohide {
            if let autohideItem = autohide.item {
                let rect = self.rectOf(item: autohideItem)
                if (documentOffset.y > (rect.minY + (rect.height / 2))) && documentOffset.y < rect.maxY {
//                    scroll(to: .top(id: autohideItem.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: autohideItem.height), completion: { [weak self] _ in
//                        self?.liveScrollStartPosition = nil
//                    })
                } else if documentOffset.y > 0 && documentOffset.y < rect.maxY {
//                    scroll(to: .top(id: autohideItem.stableId, innerId: nil, animated: true, focus: .init(focus: false), inset: 0), completion: { [weak self] _ in
//                        self?.liveScrollStartPosition = nil
//                    })
                } else {
                    liveScrollStartPosition = nil
                }
            } else {
                liveScrollStartPosition = nil
            }
        } else {
            liveScrollStartPosition = nil
        }
        liveScrollStack.removeAll()
        _scrollDidEndLiveScrolling?()
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
            let clipView = self.contentView
            
            NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: self, queue: nil, using: { [weak self] notification in
                self?.scrollDidEndLiveScrolling()
            })
            
            NotificationCenter.default.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: self, queue: nil, using: { [weak self] notification in
                self?.scrollWillStartLiveScrolling()
            })
            
            NotificationCenter.default.addObserver(forName: NSScrollView.didLiveScrollNotification, object: self, queue: nil, using: { [weak self] notification in
                self?.scrollDidLiveScrolling()
            })
            
            NotificationCenter.default.addObserver(forName: NSView.boundsDidChangeNotification, object: clipView, queue: OperationQueue.main, using: { [weak self] notification  in
                Queue.mainQueue().justDispatch { [weak self] in
                    self?.scrollDidChangedBounds()
                }
                if let strongSelf = self {
                    let reqCount = strongSelf.count / 6
                    
                    strongSelf.updateStickAfterScroll(strongSelf.nextScrollEventIsAnimated)
                    strongSelf.nextScrollEventIsAnimated = false
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
                    
                    if strongSelf.needUpdateVisibleAfterScroll {
                        let range = strongSelf.visibleRows()
                        for i in range.location ..< range.location + range.length {
                            if let view = strongSelf.viewNecessary(at: i) {
                                view.updateMouse()
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
    
    public var p_stickView: NSView? {
        return stickView
    }
    
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
                    stickView = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), stickItem.heightValue))
                    stickView!.header = true
                    stickView!.set(item: stickItem, animated: false)
                 //   tableView.addSubview(stickView!)
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
            NSAnimationContext.current.duration = 0.0
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
                    
                    self.contentView.scroll(to: NSMakePoint(0, y))
                   // reflectScrolledClipView(clipView)
                   // flashScrollers()
                    break
                }
            }
        }
    }
    
    private let stickTimeoutDisposable = MetaDisposable()
    private var previousStickMinY: CGFloat? = nil
    public func updateStickAfterScroll(_ animated: Bool) -> Void {
        let range = self.visibleRows()
        
        if let stickClass = stickClass {
         //   if documentSize.height > frame.height {
                
                let flipped = tableView.isFlipped

                
                var index:Int = flipped ? range.location : range.location + range.length - 1
                
                
                let scrollInset = self.documentOffset.y + (flipped ? 0 : frame.height)
                var item:TableRowItem? = optionalItem(at: index)
                
                if !flipped {
                    while let s = item, !s.isKind(of: stickClass) {
                        index += 1
                        item = self.optionalItem(at: index)
                    }
                } else {
                    while let s = item, !s.isKind(of: stickClass) {
                        index -= 1
                        item = self.optionalItem(at: index)
                    }
                }
               
                
                if item == nil && !flipped {
                    index = range.location + range.length
                    while item == nil && index < count {
                        if let s = self.optionalItem(at: index), s.isKind(of: stickClass) {
                            item = s
                        }
                        index += 1
                    }
                }
                
                
                if let someItem = item as? TableStickItem {
                    var currentStick:TableStickItem?
                    
                    if !flipped {
                        for index in stride(from: someItem.index - 1, to: -1, by: -1) {
                            let item = self.optionalItem(at: index)
                            if let item = item, item.isKind(of: stickClass) {
                                currentStick = item as? TableStickItem
                                break
                            }
                        }
                    } else {
                        for index in someItem.index + 1 ..< count {
                            let item = self.optionalItem(at: index)
                            if let item = item, item.isKind(of: stickClass) {
                                currentStick = item as? TableStickItem
                                break
                            }
                        }
                    }
                    
                    
                    if stickView?.item != item {
                        stickView?.set(item: someItem, animated: animated)
                        stickView?.updateIsVisible(!firstTime, animated: animated)
                    }
                    
                    if let item = stickItem {
                        if let view = (viewNecessary(at: item.index) as? TableStickView) {
                            view.updateIsVisible((!firstTime || !view.header), animated: animated)
                        }
                    }
                    
                    stickItem = currentStick ?? someItem
                    
                    if let stickView = stickView {
                        if subviews.last != stickView {
                            stickView.removeFromSuperview()
                            addSubview(stickView)
                        }
                    }
                    
                    stickView?.setFrameSize(tableView.frame.width, someItem.heightValue)
                    let itemRect:NSRect = someItem.view?.visibleRect ?? NSZeroRect

                    if let item = stickItem, item.isKind(of: stickClass), let stickView = stickView {
                        let rect:NSRect = tableView.rect(ofRow: item.index)
                        let dif:CGFloat
                        if currentStick != nil {
                            dif = min(scrollInset - rect.maxY, item.heightValue)
                        } else {
                            dif = item.heightValue
                        }
                        var yTopOffset:CGFloat
                        if !flipped {
                            yTopOffset = min((scrollInset - rect.maxY) - rect.height, 0)
                        } else {
                            yTopOffset = min(-(rect.height + (scrollInset - rect.minY)), 0)
                        }
                        if yTopOffset <= -rect.height {
                            yTopOffset = 0
                        }
                        
                        stickView.change(pos: NSMakePoint(0, yTopOffset), animated: animated)
                        stickView.header = abs(dif) <= item.heightValue

                        if !firstTime {
                            let rows:[Int] = [tableView.row(at: NSMakePoint(0, scrollInset - stickView.frame.height)), tableView.row(at: NSMakePoint(0, scrollInset))]
                            var applied: Bool = false
                            for row in rows {
                                let row = min(max(0, row), list.count - 1)
                                if let dateItem = self.item(at: row) as? TableStickItem, let view = dateItem.view as? TableStickView {
                                    view.updateIsVisible(yTopOffset < 0 && documentOffset.y > 0, animated: false)
                                    applied = true
                                }
                            }
                            if !applied {
                                self.enumerateViews(with: { view in
                                   (view as? TableStickView)?.updateIsVisible(true, animated: false)
                                   return true
                                })
                            }
                            
                        }
                        
                        
                        if previousStickMinY == nil {
                            previousStickMinY = documentOffset.y
                        }
                        
                       
                        
                        if previousStickMinY != documentOffset.y {
                            stickView.isHidden = false
                            previousStickMinY = documentOffset.y
                            if !animated || stickView.layer?.opacity != 0 {
                                stickView.updateIsVisible(true, animated: true)
                                firstTime = false
                            }
                        }
                        
                        if tableView.isFlipped {
                            
                            stickView.isHidden = documentOffset.y <= 0// && !stickView.isAlwaysUp
                        }

                        stickTimeoutDisposable.set((Signal<Void, NoError>.single(Void()) |> delay(2.0, queue: Queue.mainQueue())).start(next: { [weak stickView] in
                            
                            if itemRect.height == 0, let stickView = stickView {
                                stickView.updateIsVisible(false, animated: true)
                            }
                        }))
                        
                    }
                    
                } else  {
                    if index == -1 {
                        if animated, let stickView = self.stickView {
                            stickView.change(pos: NSMakePoint(0, -stickView.frame.height), animated: animated, removeOnCompletion: false, completion: { [weak stickView] _ in
                                stickView?.removeFromSuperview()
                            })
                        } else {
                            stickView?.removeFromSuperview()
                        }
                    } else {
                        stickView?.setFrameOrigin(0, 0)
                        stickView?.header = true
                    }
                    
                     self.enumerateViews(with: { view in
                        (view as? TableStickView)?.updateIsVisible(true, animated: false)
                        return true
                     })
                }

          //  }
        }
    }

    
    public func resetScrollNotifies() ->Void {
        self.previousScroll = nil
        updateScroll()
    }
    
    public func scrollUp(offset: CGFloat = 30.0) {
        self.clipView.scroll(to: NSMakePoint(0, min(clipView.bounds.minY + offset, clipView.bounds.maxY)), animated: true)
        self.reflectScrolledClipView(clipView)
    }
    
    
    public func scrollDown(offset: CGFloat = 30.0) {
        self.clipView.scroll(to: NSMakePoint(0, max(clipView.bounds.minY - offset, 0)), animated: true)
        self.reflectScrolledClipView(clipView)
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
        
        let hash = selectedhash
        if let hash = hash {
            return self.item(stableId:hash)
        }
        return nil
    }
    
    public func isSelected(_ item:TableRowItem) ->Bool {
        return selectedhash == item.stableId
    }
    
    public func highlightedItem() -> TableRowItem? {
        
        let hash = highlitedHash
        if let hash = hash {
            return self.item(stableId: hash)
        }
        return nil
    }
    
    public func isHighlighted(_ item:TableRowItem) ->Bool {
        return highlitedHash == item.stableId
    }
    
    public func item(stableId:AnyHashable) -> TableRowItem? {
        return self.listhash[stableId];
    }
    
    public func index(of:TableRowItem) -> Int? {
        if let it = self.listhash[of.stableId] {
            return self.list.index(of: it)
        }
        return nil
    }
    
    public func index(hash:AnyHashable) -> Int? {
        
        if let it = self.listhash[hash] {
            return it.index
        }
        
        return nil
    }
    
    fileprivate func startResorting() {
        guard let window = _window else {return}
        
        let point = tableView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        let range = tableView.rows(in: NSMakeRect(point.x, point.y, 1, 1));
        if range.length > 0, let controller = resortController, controller.canResort(range.location), let view = viewNecessary(at: range.location) {
            controller.resortRow = range.location
            controller.currentHoleIndex = range.location
            controller.resortView = view
            controller.startLocation = point
            controller.startRowLocation = view.frame.origin
            controller.start(range.location)
   
            view.frame = convert(view.frame, from: view.superview)
            addSubview(view)
            view.isHidden = false
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                guard let controller = self?.resortController, controller.isResorting else {return .rejected}
                self?.stopResorting()
                return .invoked
            }, with: self, for: .leftMouseUp, priority: .modal)
            
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                if let controller = self?.resortController, let view = controller.resortView, let `self` = self {
                    
                    self.contentView.autoscroll(with: event)
                    
                    var point = self.tableView.convert(event.locationInWindow, from: nil)
                    point.x = 0
                    let difference = (controller.startLocation.y - point.y)
                
                    if view.superview != self {
                        view.frame = self.convert(view.frame, from: view.superview)
                        view.set(item: self.item(at: range.location), animated: false)
                        controller.resortView = view
                        self.addSubview(view)
                    }
                    view.isHidden = false
                    
                    var newPoint = NSMakePoint(view.frame.minX, max(controller.startRowLocation.y - difference, 0))
                    newPoint.y -= self.documentOffset.y //self.convert(newPoint, from: self.tableView)
                    view.setFrameOrigin(newPoint)
                    self.updateMovableItem(point)
                    return .invoked
                } else {
                    return .rejected
                }
            }, with: self, for: .leftMouseDragged, priority: .modal)
            
            
        }
    }
    
    
    fileprivate func stopResorting() {
        if let controller = resortController, let current = controller.currentHoleIndex, let start = controller.resortRow {
            
            
            NSAnimationContext.runAnimationGroup({ ctx in
                if controller.resortRange.location != NSNotFound {
                    var y: CGFloat = 0
                    for i in 0 ..< controller.resortRange.location {
                        y += self.list[i].heightValue
                    }
                    for i in controller.resortRange.location ..< controller.resortRange.max  {
                        if let resortView = controller.resortView {
                            if i == current {
                                if current > start {
                                    y -= (resortView.frame.height - item(at: i).heightValue)
                                }
                                y -= self.documentOffset.y
                                let point = NSMakePoint(resortView.frame.minX, y)
                                //convert(, from: tableView)
                                resortView.animator().setFrameOrigin(point)
                                y = 0
                                break
                            }
                            y += item(at: i).heightValue
                        }
                    }
                }
            }, completionHandler: {
                let view = controller.resortView
                controller.clear()
                if let view = view {
                    view.frame = self.tableView.convert(view.frame, from: view.superview)
                    self.tableView.addSubview(view)
                }
                if controller.resortRange.location != NSNotFound {
                    controller.complete(start, current)
                }
            })
            
            
            _window?.remove(object: self, for: .leftMouseUp)
        }
    }
    

    

    private var maxResortHeight: CGFloat {
        guard let controller = resortController else {return 0}
        var height: CGFloat = 0
        for i in 0 ..< controller.resortRange.max {
            height += item(at: i).heightValue
        }
        return height
    }
    
    
    private func moveHole(at fromIndex: Int, to toIndex: Int, animated: Bool) {
        var y: CGFloat = 0
        
        
        guard let controller = resortController, let resortRow = controller.resortRow, let resortView = controller.resortView else {return}
        if controller.resortRange.location == NSNotFound {
            self.stopResorting()
            return
        }
        for i in 0 ..< controller.resortRange.location {
            y += self.list[i].heightValue
        }
        
        if toIndex > resortRow {
            
            y = maxResortHeight
            
            for i in stride(from: controller.resortRange.max - 1, to: -1, by: -1) {
                let view = viewNecessary(at: i, makeIfNecessary: false)
                if i == toIndex {
                    y -= resortView.frame.height// view.frame.height
                }
                if view != controller.resortView {
                    y -= self.item(at: i).heightValue
                    view?.animator().setFrameOrigin(0, y)
                }
            }
        } else {
            for i in controller.resortRange.location ..< controller.resortRange.max {
                let view = viewNecessary(at: i, makeIfNecessary: false)
                if i == toIndex {
                    y += resortView.frame.height
                }
                if view != controller.resortView {
                    view?.animator().setFrameOrigin(0, y)
                    y += self.item(at: i).heightValue
                }
            }
        }
        
        
    }
    
    private func updateMovableItem(_ point: NSPoint) {
        
        
        guard let controller = resortController else {return}
        
        let row = min(max(tableView.row(at: point), controller.resortRange.location), controller.resortRange.max - 1)
        controller.prevHoleIndex = controller.currentHoleIndex
        controller.currentHoleIndex = row
        if controller.prevHoleIndex != controller.currentHoleIndex {
            moveHole(at: controller.prevHoleIndex!, to: controller.currentHoleIndex!, animated: true)
            controller.updateItems(controller.resortView, self.list.filter { controller.canResort($0.index) })
        }
    }


    private var _window:Window? {
        return window as? Window
    }
    
    public func insert(item:TableRowItem, at:Int = 0, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Bool {
         assert(self.item(stableId:item.stableId) == nil, "inserting existing row inTable: \(self.item(stableId:item.stableId)!.className), new: \(item.className), stableId: \(item.stableId)")
        self.listhash[item.stableId] = item;
        let at = min(at, list.count)
        self.list.insert(item, at: at);
        item.table = self;
        item._index = at
        let animation = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current.duration = animation != .none ? 0.2 : 0.0
        
        if(redraw) {
            self.tableView.insertRows(at: IndexSet(integer: at), withAnimation: animation)
            self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: at))
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
            self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: at ..< current + at))

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
    
    
    
    public func reloadData(row:Int, animated:Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false) -> Void {
        if let view = self.viewNecessary(at: row) {
            let item = self.item(at: row)
            if view.isKind(of: item.viewClass()) && !presentAsNew {
                if view.frame.height != item.heightValue {
                    NSAnimationContext.current.duration = animated ? 0.2 : 0.0
                    tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                }
                view.change(size: NSMakeSize(frame.width, item.heightValue), animated: animated)
                view.set(item: item, animated: animated)
            } else {
                self.tableView.removeRows(at: IndexSet(integer: row), withAnimation: !animated ? .none : options)
                self.tableView.insertRows(at: IndexSet(integer: row), withAnimation: !animated ? .none :  options)
            }
        } else {
            NSAnimationContext.current.duration = 0.0
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        }
        //self.moveItem(from: row, to: row)
    }
    
    fileprivate func reloadHeightItems() {
        self.enumerateItems { item -> Bool in
            if item.reloadOnTableHeightChanged {
                self.reloadData(row: item.index)
            }
            return true
        }
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
        
        item._index = to
        
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
       // CATransaction.begin()
    }
    
    public func endUpdates() -> Void {
        updating = false
        updateScroll(visibleRows())
        self.previousScroll = nil
        
    //    CATransaction.commit()
    }
    
    public func rectOf(item:TableRowItem) -> NSRect {
        return self.tableView.rect(ofRow: item.index)
    }
    
    public func rectOf(index:Int) -> NSRect {
        return self.tableView.rect(ofRow: index)
    }
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        if at < count {
            let item = self.list.remove(at: at);
            self.listhash.removeValue(forKey: item.stableId)
            
            viewNecessary(at: at)?.onRemove(animation)
                        
            item._index = nil

            let animation: NSTableView.AnimationOptions = animation != .none ? item.animatable ? animation : .none : .none
            NSAnimationContext.current.duration = animation == .none ? 0.0 : 0.2

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
        self.tableView.removeAllSubviews()
    }
    
    public func selectNext(_ scroll:Bool = true, _ animated:Bool = false, turnDirection: Bool = true) -> Void {
        var previousInset: CGFloat = 0
        if let hash = selectedhash {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                previousInset = -selectedItem.heightValue
                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex += 1
                
                if selectedIndex == count  {
                    if turnDirection {
                        selectedIndex = 0
                    } else {
                        selectedIndex = count - 1
                    }
                }
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in sIndex ..< list.count {
                        if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false) {
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
                    if delegate.selectionWillChange(row: item.index, item: item, byClick: false) {
                        _ = self.select(item: item)
                        break
                    }
                }
            }
            
        }
        if let hash = selectedhash, scroll {
            self.scroll(to: .top(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), true)
        }
    }
    
    public func selectPrev(_ scroll:Bool = true, _ animated:Bool = false, turnDirection: Bool = true) -> Void {
        var previousInset: CGFloat = 0
        if let hash = selectedhash {
            let selectedItem = self.item(stableId: hash)
            if let selectedItem = selectedItem {
                previousInset = selectedItem.heightValue

                var selectedIndex = self.index(of: selectedItem)!
                selectedIndex -= 1
                
                if selectedIndex == -1  {
                    if turnDirection {
                        selectedIndex = count - 1
                    } else {
                        selectedIndex = 0
                    }
                }
                
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in stride(from: sIndex, to: -1, by: -1) {
                        if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false) {
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
                    if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false) {
                        _ = self.select(item: item(at: i))
                        break
                    }
                }
            }

        }
        
        if let hash = selectedhash, scroll {
            self.scroll(to: .bottom(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), true)
        }
    }
    
    public func highlightNext(_ scroll:Bool = true, _ animated:Bool = false, turnDirection: Bool = true) -> Void {
        var previousInset: CGFloat = 0
        if let hash = highlitedHash {
            let highlighteditem = self.item(stableId: hash)

            if let highlighteditem = highlighteditem {
                previousInset = -highlighteditem.heightValue
                var selectedIndex = self.index(of: highlighteditem)!
                selectedIndex += 1
                
                if selectedIndex == count  {
                    if turnDirection {
                        selectedIndex = 0
                    } else {
                        selectedIndex = count - 1
                    }
                }
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in sIndex ..< list.count {
                        if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false), selectedItem()?.index != i {
                            selectedIndex = i
                            break
                        }
                    }
                }
            
                _ = highlight(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let delegate = delegate {
                for item in list {
                    if delegate.selectionWillChange(row: item.index, item: item, byClick: false), selectedItem()?.index != item.index {
                        _ = self.highlight(item: item)
                        break
                    }
                }
            }
            
        }
        if let hash = highlitedHash, scroll {
            self.scroll(to: .top(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), true)
        }
    }
    
    public func highlightPrev(_ scroll:Bool = true, _ animated:Bool = false, turnDirection: Bool = true) -> Void {
        var previousInset: CGFloat = 0

        if let hash = highlitedHash {
            let highlightedItem = self.item(stableId: hash)
            if let highlightedItem = highlightedItem {
                previousInset = highlightedItem.heightValue
                var selectedIndex = self.index(of: highlightedItem)!
                selectedIndex -= 1
                
                if selectedIndex == -1  {
                    if turnDirection {
                        selectedIndex = count - 1
                    } else {
                        selectedIndex = 0
                    }
                }
                
                if let delegate = delegate {
                    let sIndex = selectedIndex
                    for i in stride(from: sIndex, to: -1, by: -1) {
                        if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false), selectedItem()?.index != i {
                            selectedIndex = i
                            break
                        }
                    }
                }
                
                _ = highlight(item: item(at: selectedIndex))
            }
            
            
        } else {
            if let delegate = delegate {
                for i in stride(from: list.count - 1, to: -1, by: -1) {
                    if delegate.selectionWillChange(row: i, item: item(at: i), byClick: false), selectedItem()?.index != i {
                        _ = self.highlight(item: item(at: i))
                        break
                    }
                }
            }
            
        }
        
        if let hash = highlitedHash, scroll {
            self.scroll(to: .bottom(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), true)
        }
    }
    
    
    public var isEmpty:Bool {
        
        if let emptyChecker = emptyChecker {
            return emptyChecker(self.list)
        }
        
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
            height += item.heightValue
        }
        return height
    }
    
    public func row(at point:NSPoint) -> Int {
        return tableView.row(at: NSMakePoint(point.x, point.y - bottomInset))
    }
    
    public func viewNecessary(at row:Int, makeIfNecessary: Bool = false) -> TableRowView? {
        if row < 0 || row >= count {
            if row == -1000 {
                return emptyView
            }
            return nil
        }
        if let resortView = self.resortController?.resortView {
            if resortView.item?.stableId == self.item(at: row).stableId {
                return resortView
            }
        }
        return self.tableView.rowView(atRow: row, makeIfNecessary: makeIfNecessary) as? TableRowView
    }
    
    
    public func select(item:TableRowItem, notify:Bool = true, byClick:Bool = false) -> Bool {
        
        if let delegate = delegate, delegate.isSelectable(row: item.index, item: item) {
            if(self.item(stableId:item.stableId) != nil) {
                if !notify || delegate.selectionWillChange(row: item.index, item: item, byClick: byClick) {
                    let new = item.stableId != selectedhash
                    if new {
                        self.cancelSelection();
                    }
                    self.selectedhash = item.stableId
                    if highlightedItem() != nil {
                        _ = highlight(item: item)
                    }
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
    
    public func highlight(item:TableRowItem, notify:Bool = true, byClick:Bool = false) -> Bool {
        
        if let delegate = delegate, delegate.isSelectable(row: item.index, item: item) {
            if(self.item(stableId:item.stableId) != nil) {
                if !notify || delegate.selectionWillChange(row: item.index, item: item, byClick: byClick) {
                    let new = item.stableId != selectedhash
                    if new {
                        self.cancelHighlight();
                    }
                    highlitedHash = item.stableId
                    item.prepare(true)
                    self.reloadData(row:item.index)
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
                self.selectedhash = stableId
            }
        } else {
            cancelSelection()
        }
    }
    
    public func cancelSelection() -> Void {
        if let hash = selectedhash {
            if let item = self.item(stableId: hash) {
                item.prepare(false)
                selectedhash = nil
                self.reloadData(row:item.index)
            } else {
                selectedhash = nil
            }
        }
        
    }
    
    public func cancelHighlight() -> Void {
        if let hash = highlitedHash {
            if let item = self.item(stableId: hash) {
                item.prepare(false)
                highlitedHash = nil
                self.reloadData(row: item.index)
            } else {
                highlitedHash = nil
            }
        }
        
    }
    
    
    func rowView(item:TableRowItem) -> TableRowView {
        let identifier:String = item.identifier
        
        if let resortView = self.resortController?.resortView {
            if resortView.item?.stableId == item.stableId {
                return resortView
            }
        }
        
        var view: NSView? = item.isUniqueView ? nil : self.tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: identifier), owner: self.tableView)

        if(view == nil) {
            view = makeView(at: item.index)
            view?.identifier = NSUserInterfaceItemIdentifier(rawValue: identifier)
        }
        if view!.frame.height != item.heightValue {
            view?.setFrameSize(NSMakeSize(frame.width, item.heightValue))
        }
        return view as! TableRowView;
    }
    
    private func makeView(at index: Int) -> TableRowView {
        let item = self.item(at: index)
        let vz = item.viewClass() as! TableRowView.Type
        let view = vz.init(frame:NSMakeRect(0, 0, frame.width, item.heightValue))
        return view
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        return self.count;
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return max(self.item(at: row).heightValue, 1)
    }
    
    public func tableView(_ tableView: NSTableView, isGroupRow row: Int) -> Bool {
        return false;
    }
    
    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        return nil
    }
    

  
    public func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let item: TableRowItem = self.item(at: row);
        
        let view: TableRowView = self.rowView(item: item);
        
        self.beforeSetupItem?(view, item)
        
        view.set(item: item, animated: false)
        
        self.afterSetupItem?(view, item)

        
        return view
    }

    
    func visibleItems() -> [(TableRowItem,CGFloat,CGFloat)]  { // item, top offset, bottom offset
        
        var list:[(TableRowItem,CGFloat,CGFloat)] = []
        
        let visible = visibleRows()
        
        for i in visible.min ..< visible.max {
            let item = self.item(at: i)
            let rect = rectOf(index: i)
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
    
    public func merge(with transition:Signal<TableUpdateTransition, NoError>) {
        mergePromise.set(transition |> deliverOnMainQueue)
    }
    
    public var isBoundsAnimated: Bool {
        return contentView.layer?.animation(forKey: "bounds") != nil
    }
    
    private var first:Bool = true
    
    private var queuedTransitions: [TableUpdateTransition] = []
    private var areSuspended = false
    private var isAlreadyEnqued: Bool = false
    private func enqueueTransitions() {
        
        guard !isAlreadyEnqued else {
            return
        }
        
        isAlreadyEnqued = true
        while !queuedTransitions.isEmpty {
            if !isSetTransitionToQueue() && !updating {
                self.merge(with: queuedTransitions.removeFirst(), forceApply: true)
            } else {
                break
            }
        }
        isAlreadyEnqued = false
    }
    
    private func isSetTransitionToQueue() -> Bool {
        return areSuspended
    }
    
    public func merge(with transition:TableUpdateTransition) -> Void {
        self.merge(with: transition, forceApply: false)
        enqueueTransitions()
    }
    
    private func merge(with transition:TableUpdateTransition, forceApply: Bool) -> Void {
        
        assertOnMainThread()
        assert(!updating)
        
        if isSetTransitionToQueue() || (!self.queuedTransitions.isEmpty && !forceApply) {
            self.queuedTransitions.append(transition)
            return
        }
        
        let oldEmpty = self.isEmpty
        
//        for subview in tableView.subviews.reversed() {
//            if let subview = subview as? NSTableRowView {
//                if tableView.row(for: subview) == -1 {
//                    subview.removeFromSuperview()
//                }
//            }
//        }

        
        self.beginUpdates()
        
        let documentOffset = self.documentOffset
        
        let visibleItems = self.visibleItems()
        let visibleRange = self.visibleRows()
        if transition.grouping && !transition.isEmpty {
            self.tableView.beginUpdates()
        }
        //CATransaction.begin()
        
        
        for (i, item) in list.enumerated() {
            item._index = nil
        }

        var inserted:[(TableRowItem, NSTableView.AnimationOptions)] = []
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
        
        //NSAnimationContext.current.duration = transition.animated ? 0.2 : 0.0
        

        for (idx,item) in transition.inserted {
            let effect:NSTableView.AnimationOptions = (visibleRange.indexIn(idx - 1) || !transition.animateVisibleOnly) && transition.animated ? .effectFade : .none
            _ = self.insert(item: item, at:idx, redraw: true, animation: effect)
            if item.animatable {
                inserted.append((item, effect))
            }
        }
        
        
        for (index,item) in transition.updated {
            let animated:Bool
            if case .none = transition.state {
                animated = visibleRange.indexIn(index) || !transition.animateVisibleOnly
            } else {
                animated = false
            }
            replace(item:item, at:index, animated: animated)
        }

        
        for (i, item) in list.enumerated() {
            item._index = i
        }
        
        //CATransaction.commit()
        if transition.grouping && !transition.isEmpty {
            self.tableView.endUpdates()
        }
        self.clipView.justScroll(to: documentOffset)

        
        
        for inserted in inserted {
            inserted.0.view?.onInsert(inserted.1)
        }
        
        
        let state: TableScrollState
        
        if case .none = transition.state, !transition.deleted.isEmpty || !transition.inserted.isEmpty {
            let isSomeOfItemVisible = !inserted.filter({$0.0.isVisible}).isEmpty || !removed.filter({$0.isVisible}).isEmpty
            if isSomeOfItemVisible {
                state = transition.state
            } else {
                state = transition.state
               // state = .saveVisible(.upper)
            }
        } else {
            state = transition.state
        }
        
       // NSLog("listHeight: \(listHeight), scroll: \(state)")
      //  self.tableView.beginUpdates()
        
        func saveVisible(_ side: TableSavingSide) {
            var nrect:NSRect = NSZeroRect
            
            let strideTo:StrideTo<Int>
            
            var aroundIndex: AnyHashable?
            
            if !tableView.isFlipped {
                switch side {
                case .lower:
                    strideTo = stride(from: 0, to: visibleItems.count, by: 1)
                case .upper:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .aroundIndex(let index):
                    aroundIndex = index
                    strideTo = stride(from: 0, to: visibleItems.count, by: 1)
                }
            } else {
                switch side {
                case .upper:
                    strideTo = stride(from: visibleItems.count - 1, to: -1, by: -1)
                case .lower:
                    strideTo = stride(from: 0, to: visibleItems.count, by: 1)
                case .aroundIndex(let index):
                    aroundIndex = index
                    strideTo = stride(from: 0, to: visibleItems.count, by: 1)
                }
            }
            
            
            for i in strideTo {
                let visible = visibleItems[i]
                
                if let aroundIndex = aroundIndex {
                    if aroundIndex != visible.0.stableId {
                        continue
                    }
                }
                if let item = self.item(stableId: visible.0.stableId) {
                    
                    if !item.canBeAnchor {
                        continue
                    }
                    
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
                    self.clipView.scroll(to: NSMakePoint(0, y), animated: false)

                    //reflectScrolledClipView(clipView)
//                    tile()
                    //self.contentView.bounds = NSMakeRect(0, y, 0, contentView.bounds.height)
                    //self.display(visi)
                   // reflectScrolledClipView(clipView)
                    
                   // let assertRect = rectOf(item: item)
                   // let top = frame.height - (assertRect.minY - documentOffset.y) - assertRect.height
                    
                   // assert(visible.1 == top)
                    
                  //  tableView.tile()
                  //  tableView.display()
                    break
                }
            }
        }
        switch state {
        case let .none(animation):
            // print("scroll do nothing")
            animation?.animate(table:self, documentOffset: documentOffset, added: inserted.map{ $0.0 }, removed:removed)
            if let animation = animation, !animation.scrollBelow, !transition.isEmpty, contentView.bounds.minY > 0 {
                saveVisible(.upper)
            }
        case .bottom, .top, .center:
            self.scroll(to: transition.state)
        case .up, .down, .upOffset:
            self.scroll(to: transition.state)
        case let .saveVisible(side):
            saveVisible(side)
            
            break
        }
        //reflectScrolledClipView(clipView)
     //   self.tableView.endUpdates()
        self.endUpdates()
        
        
//        for subview in self.tableView.subviews.reversed() {
//            if self.tableView.row(for: subview) == -1 {
//                subview.removeFromSuperview()
//            }
//        }
        
        if oldEmpty != isEmpty || first {
            updateEmpties(animated: !first)
        }
        
        if let searchState = transition.searchState {
            if self.searchView == nil {
                self.searchView = TableSearchView(frame: NSMakeRect(0, -50, frame.width, 50))
                addSubview(self.searchView!)
            }
            guard let searchView = self.searchView else {
                return
            }
            switch searchState {
            case .none:
                searchView.change(pos: NSMakePoint(0, -searchView.frame.height), animated: true)
                searchView.searchView.cancel(true)
            case let .visible(data):
                searchView.change(pos: NSZeroPoint, animated: true)
                searchView.applySearchResponder()
                searchView.updateDatas(data)
            }
        } else {
            self.searchView?.removeFromSuperview()
            self.searchView = nil
        }
        
        first = false
        performScrollEvent(transition.animated)
    }
    
    public func updateEmpties(animated: Bool = false) {
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
                    if animated, let emptyView = emptyView {
                        emptyView.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
                    }
                }
                
                if emptyView?.superview == nil {
                    addSubview(emptyView!)
                }
                
                if let emptyView = emptyView, let superview = superview {
                    emptyView.frame = findBackgroundControllerView?.bounds ?? bounds
                    emptyView.centerX(y: superview.frame.height - emptyView.frame.height)
                    
                    if animated {
                        emptyView.layer?.animatePosition(from: emptyView.frame.origin.offsetBy(dx: 0, dy: 25), to: emptyView.frame.origin)
                    }
                }
               
                
                emptyView?.set(item: emptyItem)
                emptyView?.needsLayout = true
                
                tableView._change(opacity: 0, animated: animated)
            } else {
                if let emptyView = emptyView {
                    self.emptyView = nil
                    if animated {
                        emptyView.layer?.animateAlpha(from: 1, to: 0, duration: 0.2, removeOnCompletion: false, completion: { [weak emptyView] completed in
                            emptyView?.removeFromSuperview()
                        })
                        if animated {
                            emptyView.layer?.animatePosition(from: emptyView.frame.origin, to: emptyView.frame.origin.offsetBy(dx: 0, dy: 25), removeOnCompletion: false)
                        }
                    } else {
                        emptyView.removeFromSuperview()
                    }
                }
                tableView._change(opacity: 1, animated: animated)
            }
        }
        
    }
    
    
    public func replace(item:TableRowItem, at index:Int, animated:Bool) {
        if index < count {
            listhash.removeValue(forKey: list[index].stableId)
            list[index] = item
            listhash[item.stableId] = item
            item.table = self
            item._index = index
            reloadData(row: index, animated: animated)
        }
    }

    public func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        var item = self.item(stableId: stableId)
        
        if item == nil {
            if let groupStableId = delegate?.findGroupStableId(for: stableId) {
                item = self.item(stableId: groupStableId)
            }
        }
        
        if let item = item {
            let view = viewNecessary(at:item.index)
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                return view.interactionContentView(for: stableId, animateIn: animateIn)
            }
           
        }
        
        return nil
    }
    
    public func interactionControllerDidFinishAnimation(interactive: Bool, for stableId: AnyHashable) {
        var item = self.item(stableId: stableId)
        
        if item == nil {
            if let groupStableId = delegate?.findGroupStableId(for: stableId) {
                item = self.item(stableId: groupStableId)
            }
        }
        
        if let item = item {
            let view = viewNecessary(at:item.index)
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                view.interactionControllerDidFinishAnimation(interactive: interactive, innerId: stableId)
            }
        }
    }
    
    public func addAccesoryOnCopiedView(for stableId: AnyHashable, view: NSView) {
        var item = self.item(stableId: stableId)

        if item == nil {
            if let groupStableId = delegate?.findGroupStableId(for: stableId) {
                item = self.item(stableId: groupStableId)
            }
        }
        
        if let item = item {
            let rowView = viewNecessary(at:item.index)
            if let rowView = rowView, !NSIsEmptyRect(view.visibleRect) {
                rowView.addAccesoryOnCopiedView(innerId: stableId, view: view)
            }
        }
    }
    
    public func videoTimebase(for stableId: AnyHashable) -> CMTimebase? {
        var item = self.item(stableId: stableId)
        
        if item == nil {
            if let groupStableId = delegate?.findGroupStableId(for: stableId) {
                item = self.item(stableId: groupStableId)
            }
        }
        
        if let item = item {
            let view = viewNecessary(at:item.index)
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                return view.videoTimebase(for: stableId)
            }
            
        }
        
        return nil
    }
    
    public func applyTimebase(for stableId: AnyHashable, timebase: CMTimebase?) {
        var item = self.item(stableId: stableId)
        
        if item == nil {
            if let groupStableId = delegate?.findGroupStableId(for: stableId) {
                item = self.item(stableId: groupStableId)
            }
        }
        
        if let item = item {
            let view = viewNecessary(at:item.index)
            if let view = view, !NSIsEmptyRect(view.visibleRect) {
                view.applyTimebase(for: stableId, timebase: timebase)
            }
        }
        
    }

    func selectRow(index: Int) {
        if self.count > index {
            _ = self.select(item: self.item(at: index), byClick:true)
        }
    }
    
    public override func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        
        
        if animated {

            if !tableView.isFlipped {
                
                CATransaction.begin()
                var presentBounds:NSRect = self.layer?.bounds ?? self.bounds
                let presentation = self.layer?.presentation()
                if let presentation = presentation, self.layer?.animation(forKey:"bounds") != nil {
                    presentBounds = presentation.bounds
                }
                
                self.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, self.bounds.minY, size.width, size.height), duration: duration, timingFunction: timingFunction)
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
                
                contentView.layer?.animateBounds(from: presentBounds, to: NSMakeRect(0, contentView.bounds.minY, size.width, size.height), duration: duration, timingFunction: timingFunction, removeOnCompletion: removeOnCompletion, forKey: "bounds", completion: { completed in
                    completion?(completed)
                })
                CATransaction.commit()
            } else {
                super.change(size: size, animated: animated, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
                return
            }
        }
        self.setFrameSize(size)
        self.updateStickAfterScroll(animated)
    }
    
    
    
    public func scroll(to state:TableScrollState, inset:NSEdgeInsets = NSEdgeInsets(), timingFunction: CAMediaTimingFunctionName = .spring, _ toVisible:Bool = false, ignoreLayerAnimation: Bool = false, completion: @escaping(Bool)->Void = { _ in }) {
       // if let index = self.index(of: item) {
        
        var rowRect:NSRect = bounds
        
        var item:TableRowItem?
        var animate:Bool = false
        var focus: TableScrollFocus = .init(focus: false)
        var relativeInset: CGFloat = 0
        var innerId: AnyHashable? = nil
        switch state {
        case let .center(stableId, _innerId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
        case let .bottom(stableId, _innerId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
        case let .top(stableId, _innerId, _animate, _focus, _inset):
            item = self.item(stableId: stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
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
        case let .upOffset(_animate, offset):
            animate = _animate
            if !tableView.isFlipped {
                rowRect.origin = NSMakePoint(0, max(documentSize.height,frame.height))
            } else {
                rowRect.origin = NSZeroPoint
            }
            relativeInset = offset
        default:
            fatalError("for scroll to item, you can use only .top, center, .bottom enumeration")
        }
        
        let bottomInset = self.bottomInset != 0 ? (self.bottomInset) : 0
        let height:CGFloat = self is HorizontalTableView ? frame.width : frame.height

        if let item = item {
            rowRect = self.rectOf(item: item)
            var state = state
            if case let .center(id, innerId, animated, focus, inset) = state, rowRect.height > frame.height {
                state = .top(id: id, innerId: innerId, animated: animated, focus: focus, inset: inset)
            }
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
                    rowRect.origin.y -= floorToScreenPixels(backingScaleFactor, (height - rowRect.height) / 2.0) - bottomInset
                } else {
                    
                    if rowRect.maxY > height/2.0 {
                        rowRect.origin.y -= floorToScreenPixels(backingScaleFactor, (height - rowRect.height) / 2.0) - bottomInset
                    } else {
                        rowRect.origin.y = 0
                    }
                    

                   // fatalError("not implemented")
                }
    
            default:
                fatalError("not implemented")
            }
            
            if toVisible  {
                let view = self.viewNecessary(at: item.index)
                if let view = view, view.visibleRect.height == item.heightValue {
                    if focus.focus {
                        view.focusAnimation(innerId)
                        focus.action?(view.interactableView)
                    }
                    completion(true)
                    return
                }
            }
        }
        rowRect.origin.y = round(min(max(rowRect.minY + relativeInset, 0), documentSize.height - height) + inset.top)
        if clipView.bounds.minY != rowRect.minY {
            
            var applied = false
            let scrollListener = TableScrollListener({ [weak self, weak item] position in
                if let item = item, !applied {
                    if let view = self?.viewNecessary(at: item.index), view.visibleRect.height > 10 {
                        applied = true
                        if focus.focus {
                            view.focusAnimation(innerId)
                            focus.action?(view.interactableView)
                        }
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
            
            let shouldSuspend: Bool
            switch state {
            case .down, .up:
                shouldSuspend = false
            default:
                shouldSuspend = true
            }
            
//            clipView.scroll(to: bounds.origin, animated: animate, completion: { [weak self] _ in
//                self?.removeScroll(listener: scrollListener)
//            })
            
            if abs(bounds.minY - clipView.bounds.minY) < height || ignoreLayerAnimation {
                if animate {
                    areSuspended = shouldSuspend
                    clipView.scroll(to: bounds.origin, animated: animate, completion: { [weak self] completed in
                        if let `self` = self {
                            scrollListener.handler(self.scrollPosition().current)
                            self.removeScroll(listener: scrollListener)
                            completion(completed)
                            self.areSuspended = false
                            self.enqueueTransitions()
                        }
                        
                    })
                } else {
                    self.contentView.scroll(to: bounds.origin)
                    reflectScrolledClipView(clipView)
                    removeScroll(listener: scrollListener)
                }
               
            } else {
               
                areSuspended = shouldSuspend
                let edgeRect:NSRect = NSMakeRect(clipView.bounds.minX, bounds.minY - getEdgeInset() - frame.minY, clipView.bounds.width, clipView.bounds.height)
                clipView._changeBounds(from: edgeRect, to: bounds, animated: animate, duration: 0.4, timingFunction: timingFunction, completion: { [weak self] completed in
                    self?.removeScroll(listener: scrollListener)
                    completion(completed)
                    self?.areSuspended = false
                    self?.enqueueTransitions()
                })

            }
        } else {
            if let item = item, focus.focus {
                if let view = viewNecessary(at: item.index) {
                    view.focusAnimation(innerId)
                    focus.action?(view.interactableView)
                }
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
    
    
    public func enumerateItems(with callback:(TableRowItem)->Bool) {
        for item in list {
            if !callback(item) {
                break
            }
        }
    }
    
    public func enumerateItems(reversed: Bool = false, with callback:(TableRowItem)->Bool) {
        if reversed {
            for item in list.reversed() {
                if !callback(item) {
                    break
                }
            }
        } else {
            for item in list {
                if !callback(item) {
                    break
                }
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
    
    public func enumerateVisibleViews(with callback:(TableRowView)->Void, force: Bool = false) {
        let visibleRows = self.visibleRows()
        for index in visibleRows.location ..< visibleRows.location + visibleRows.length {
            if let view = viewNecessary(at: index, makeIfNecessary: force) {
                callback(view)
            }
        }
    }
    
    public func performScrollEvent(_ animated: Bool = false) -> Void {
        self.nextScrollEventIsAnimated = animated
        self.updateScroll(visibleRows())
        //NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self.contentView)
    }
    
    deinit {
        mergeDisposable.dispose()
        stickTimeoutDisposable.dispose()
    }
    
    
    
}
