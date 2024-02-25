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

private let duration: Double = 0.2

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

public enum TableBackgroundMode: Equatable {
    case plain
    case color(color: NSColor)
    case gradient(colors: [NSColor], rotation: Int32?)
    case background(image: NSImage, intensity: Int32?, colors: [NSColor]?, rotation: Int32?)
    case tiled(image: NSImage)
    public var hasWallpaper: Bool {
        switch self {
        case .plain:
            return false
        case .color:
            return false
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
        self.inserted = inserted
        self.updated = updated
        self.deleted = deleted
        self.animateVisibleOnly = animateVisibleOnly
    }
    
    deinit {
        var bp:Int = 0
        bp += 1
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
    let updateState: (SearchState?)->Void
    public init(cancelImage: CGImage? = nil, cancel: @escaping()->Void, updateState: @escaping(SearchState?)->Void) {
        self.cancelImage = cancelImage
        self.cancel = cancel
        self.updateState = updateState
    }
}

public enum TableSearchViewState : Equatable {
    case none((SearchState?)->Void)
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
    public let isPartOfTransition: Bool
    public let isOnMainQueue: Bool
    fileprivate let uniqueId = arc4random64()
    public init(deleted:[Int], inserted:[(Int,TableRowItem)], updated:[(Int,TableRowItem)], animated:Bool = false, state:TableScrollState = .none(nil), grouping:Bool = true, animateVisibleOnly: Bool = false, searchState: TableSearchViewState? = nil, isPartOfTransition: Bool = false) {
        self.animated = animated
        self.state = state
        self.grouping = grouping
        self.searchState = searchState
        self.isPartOfTransition = isPartOfTransition
        self.isOnMainQueue = Queue.mainQueue().isCurrent()
        super.init(deleted: deleted, inserted: inserted, updated: updated, animateVisibleOnly: animateVisibleOnly)
    }
    public override var description: String {
        return "inserted: \(inserted.count), updated:\(updated.count), deleted:\(deleted.count), state: \(state), animated: \(animated)"
    }
    
    public func withUpdatedState(_ state: TableScrollState) -> TableUpdateTransition {
        return .init(deleted: self.deleted, inserted: self.inserted, updated: self.updated, animated: self.animated, state: state, grouping: self.grouping, animateVisibleOnly: self.animateVisibleOnly, searchState: self.searchState)
    }
    
    public static var Empty: TableUpdateTransition {
        return .init(deleted: [], inserted: [], updated: [])
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

public protocol TableViewDelegate : AnyObject {
    
    func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void;
    func selectionWillChange(row:Int, item:TableRowItem, byClick:Bool) -> Bool;
    func isSelectable(row:Int, item:TableRowItem) -> Bool;
    
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable?
    
    func longSelect(row:Int, item:TableRowItem) -> Void
}

public extension TableViewDelegate {
    func findGroupStableId(for stableId: AnyHashable) -> AnyHashable? {
        return nil
    }
    func longSelect(row:Int, item:TableRowItem) -> Void {
        
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
    let string: String?
    let action:((NSView)->Void)?
    public init(focus: Bool, string: String? = nil, action: ((NSView)->Void)? = nil) {
        self.focus = focus
        self.action = action
        self.string = string
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
    
    public static var CenterEmpty: TableScrollState {
        return .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true), inset: 0)
    }
    public static func CenterEmptyAction(_ action: @escaping (NSView)->Void)-> TableScrollState {
        return .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true, action: action), inset: 0)
    }
    public static func CenterActionEmpty(_ f:@escaping(NSView)->Void) -> TableScrollState {
        return .center(id: 0, innerId: nil, animated: true, focus: .init(focus: true, action: f), inset: 0)
    }
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
    func text(string: String?) -> TableScrollState {
        switch self {
        case let .top(stableId, innerId, animated, focus, inset):
            return .top(id: stableId, innerId: innerId, animated: animated, focus: .init(focus: focus.focus, string: string, action: focus.action), inset: inset)
        case let .bottom(stableId, innerId, animated, focus, inset):
            return .bottom(id: stableId, innerId: innerId, animated: animated, focus: .init(focus: focus.focus, string: string, action: focus.action), inset: inset)
        case let .center(stableId, innerId, animated, focus, inset):
            return .center(id: stableId, innerId: innerId, animated: animated, focus: .init(focus: focus.focus, string: string, action: focus.action), inset: inset)
        default:
            return self
        }
    }
    
    func offset(_ inset: CGFloat) -> TableScrollState {
        switch self {
        case let .top(stableId, innerId, animated, focus, v):
            return .top(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: v + inset)
        case let .bottom(stableId, innerId, animated, focus, v):
            return .bottom(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: v + inset)
        case let .center(stableId, innerId, animated, focus, v):
            return .center(id: stableId, innerId: innerId, animated: animated, focus: focus, inset: v + inset)
        default:
            return self
        }
    }
    
    var isNone: Bool {
        switch self {
        case let .none(animation):
            return animation != nil
        default:
            return false
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


protocol SelectDelegate : AnyObject {
    func selectRow(index:Int) -> Void;
    func longAction(index:Int) -> Void;
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
        usesAlternatingRowBackgroundColors = false
        layerContentsRedrawPolicy = .never
        if #available(macOS 13.0, *) {
            usesAutomaticRowHeights = false
        }
    }
    
    override func becomeFirstResponder() -> Bool {
        return false
    }
    
    override func rect(ofRow row: Int) -> NSRect {
        return super.rect(ofRow: row)
    }
    override func row(at point: NSPoint) -> Int {
        return super.row(at: point)
    }
    override func rows(in rect: NSRect) -> NSRange {
        return super.rows(in: rect)
    }
    
    override func isAccessibilityElement() -> Bool {
        return false
    }
    override func accessibilityParent() -> Any? {
        return nil
    }
    
    override public static var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    var _mouseDownCanMoveWindow: Bool = false
    override var mouseDownCanMoveWindow: Bool {
        return _mouseDownCanMoveWindow
    }
    
    override var isFlipped: Bool {
        return flip
    }
    
//    override func draw(_ dirtyRect: NSRect) {
//
//    }
    override var isOpaque: Bool {
        return false
    }

    
    override func hitTest(_ point: NSPoint) -> NSView? {
        return super.hitTest(point)
    }
    
    override func addSubview(_ view: NSView) {
        super.addSubview(view)
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
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
    private var offsetOfStartItem: NSPoint = .zero
    private var mouseDown: Bool = false
    override func mouseDragged(with event: NSEvent) {
        super.mouseDragged(with: event)
        
        if let resortController = table?.resortController, beforeRange.length > 0, mouseDown {
            if resortController.resortRange.indexIn(beforeRange.location) {
                let point = self.convert(event.locationInWindow, from: nil)
                let afterRange = self.rows(in: NSMakeRect(point.x, point.y, 1, 1))
                if afterRange != beforeRange {
                    self.table?.startResorting(beforeRange, point.offsetBy(dx: -offsetOfStartItem.x, dy: -offsetOfStartItem.y))
                }
            }
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 1 {
            mouseDown = true
            let point = self.convert(event.locationInWindow, from: nil)
            let beforeRange = self.rows(in: NSMakeRect(point.x, point.y, 1, 1))
            self.beforeRange = beforeRange
            if beforeRange.length > 0 {
                if let resortController = table?.resortController{
                    if resortController.resortRange.indexIn(beforeRange.location) {
                        self.offsetOfStartItem = point
                    } else if let table = table, !table.alwaysOpenRowsOnMouseUp {
                        sdelegate?.selectRow(index: beforeRange.location)
                    }
                } else if let table = table, !table.alwaysOpenRowsOnMouseUp {
                    sdelegate?.selectRow(index: beforeRange.location)
                }
                
                let signal: Signal<Void, NoError> = .complete() |> delay(0.5, queue: .mainQueue())
                longDisposable.set(signal.start(completed: { [weak self] in
                    guard let `self` = self, let window = self.window else {
                        return
                    }
                    let point = self.convert(window.mouseLocationOutsideOfEventStream, from: nil)
                    let afterRange = self.rows(in: NSMakeRect(point.x, point.y, 1, 1))
                    
                    if afterRange == beforeRange {
                        self.sdelegate?.longAction(index: afterRange.location)
                    }
                }))
                
            }
        }
    }
    
    override func mouseUp(with event: NSEvent) {
        longDisposable.set(nil)
        let point = self.convert(event.locationInWindow, from: nil)
        let range = self.rows(in: NSMakeRect(point.x, point.y, 1, 1));
        if range.length > 0, let table = table, mouseDown {
            mouseDown = false
            if let controller = self.table?.resortController {
                if !controller.resortRange.indexIn(range.location) {
                    if controller.resortRow == nil, beforeRange.location == range.location && table.alwaysOpenRowsOnMouseUp {
                        sdelegate?.selectRow(index: range.location)
                    }
                    return
                }
                if range.length > 0, beforeRange.location == range.location {
                    sdelegate?.selectRow(index: range.location)
                }
            } else if table.alwaysOpenRowsOnMouseUp, beforeRange.location == range.location {
                sdelegate?.selectRow(index: range.location)
            }
        }
        mouseDown = false
    }
    
    
    deinit {
        longDisposable.dispose()
    }
    
    
    
    var liveWidth:CGFloat = 0
    
    override func viewWillStartLiveResize() {
        super.viewWillStartLiveResize()
        liveWidth = frame.width
    }
    
    
    override func viewDidEndLiveResize() {
        super.viewDidEndLiveResize()
        if liveWidth != frame.width {
            liveWidth = frame.width
            table?.layoutItems()
        }
    }
    
    override func layout() {
        super.layout()
    }
    
    
   

}

public protocol InteractionContentViewProtocol : AnyObject {
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
    fileprivate var dispatchRange: NSRange = NSMakeRange(NSNotFound, 0)
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
    
    public var supplyment: InteractionContentViewProtocol? = nil

    var list:[TableRowItem] = [TableRowItem]();
    var tableView:TGFlipableTableView
    
    public var view: NSTableView {
        return tableView
    }
    
    
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

    public var isUpdating: Bool {
        return self.updating
    }
    private var updating:Bool = false
    
    private var previousScroll:ScrollPosition?
    public var needUpdateVisibleAfterScroll:Bool = false
    private var scrollHandler:(_ scrollPosition:ScrollPosition) ->Void = {_ in}
    
    private var backgroundView: ImageView?
    
    private var scrollListeners:[TableScrollListener] = []
    
    public var alwaysOpenRowsOnMouseUp: Bool = true
    
    public var autohide: TableAutohide?
    
    public var emptyChecker: (([TableRowItem]) -> Bool)? = nil
    
    public var updatedItems:(([TableRowItem])->Void)? {
        didSet {
            updatedItems?(self.list)
        }
    }
    
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
        stickView?.updateColors()
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
        self.tableView = TGFlipableTableView(frame: frameRect.size.bounds)
        self.tableView.wantsLayer = true
        self.tableView.autoresizesSubviews = false
        super.init(frame: frameRect)
        self.autoresizingMask = []
        updateAfterInitialize(isFlipped:true, drawBorder: false)
    }
    
    public init(frame frameRect: NSRect, isFlipped:Bool = true, bottomInset:CGFloat = 0, drawBorder: Bool = false) {
        self.tableView = TGFlipableTableView(frame: frameRect.size.bounds)
        self.tableView.wantsLayer = true
        self.tableView.autoresizesSubviews = false
        super.init(frame: frameRect)
        self.autoresizingMask = []
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

//        self.tableView.setFrameSize(NSMakeSize(frame.width, self.tableView.frame.height))
        
        self.tableView.flip = isFlipped
        if #available(macOS 11.0, *) {
            self.tableView.style = .fullWidth
        }
        self.automaticallyAdjustsContentInsets = false
       // tableView.translatesAutoresizingMaskIntoConstraints = false

        clipView.autoresizingMask = []
        clipView.autoresizesSubviews = false
        
        self.tableView.autoresizingMask = []
        self.tableView.rowSizeStyle = .custom

        
        self.clipView.scrollDidComplete = { [weak self] _ in
            self?.enqueueAwaitingIfNeeded()
        }
        
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
//        self.tableView.autoresizingMask = [.height]
//        self.autoresizingMask = [.width, .height]
        

        
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.sdelegate = self
        self.tableView.allowsColumnReordering = false
        self.tableView.headerView = nil;
        self.tableView.intercellSpacing = NSMakeSize(0, 0)
        self.tableView.columnAutoresizingStyle = .noColumnAutoresizing
//        let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: "column"))
//        tableColumn.width = frame.width
//
//        self.tableView.addTableColumn(tableColumn)
       
        
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
        
        self.beginTableUpdates()
        let item = TableRowItem(.zero, stableId: arc4random64())
        let _ = self.addItem(item: item)
        self.remove(at: self.count - 1)
        self.endTableUpdates()
        
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
        
        
        let visibleItems = self.visibleItems()
        beginTableUpdates()
        for i in range.min ..< range.max {
            let item = self.item(at: i)
            let before = item.heightValue
            let updated = item.makeSize(frame.width, oldWidth: oldWidth)
            let after = item.heightValue
            if (before != after && updated) || item.instantlyResize || inLiveResize {
                reloadData(row: i, animated: false)
                noteHeightOfRow(i, false)
            }
        }
        endTableUpdates()
        if !tableView.inLiveResize && oldWidth != 0 {
            saveScrollState(visibleItems)
        }
        
        for listener in scrollListeners {
            listener.handler(self.scrollPosition().current)
        }
    }
    
    private var liveScrollStartPosition: NSPoint?
    
    public func resetLiveScroll() {
        liveScrollStartPosition = nil
    }
    
    
    public var _scrollWillStartLiveScrolling:(()->Void)?
    public var _scrollDidLiveScrolling:(()->Void)?
    public var _scrollDidEndLiveScrolling:(()->Void)?
    
    public private(set) var liveScrolling: Bool = false

    open func scrollWillStartLiveScrolling() {
        self.clipView.cancelScrolling()
        liveScrollStartPosition = documentOffset
        _scrollWillStartLiveScrolling?()
        liveScrolling = true
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
    private var beginPendingTime:CFAbsoluteTime?
    private var dispatchRange: NSRange = NSMakeRange(NSNotFound, 0)
    
    public var scrollDidUpdate: ((ScrollPosition)->Void)? = nil

    
    private func updateScroll() {
        

        self.scrollDidChangedBounds()

        if self.updating == true {
            return
        }
        var isNextCallLocked: Bool {
            if let beginPendingTime = beginPendingTime {
                if CFAbsoluteTimeGetCurrent() - beginPendingTime < 0.05 {
                    return false
                }
            }
            beginPendingTime = CFAbsoluteTimeGetCurrent()
            return false
        }
        
        let reqCount = self.count / 6
        
        self.updateStickAfterScroll(self.nextScrollEventIsAnimated)
        self.nextScrollEventIsAnimated = false
        let scroll = self.scrollPosition(self.visibleRows())
        
        if (!self.updating && !self.clipView.isAnimateScrolling) {
            
            let range = scroll.current.visibleRows
            
            if range.location == NSNotFound {
                return;
            }
            
            if(scroll.current.direction != self.previousScroll?.direction && scroll.current.rect != self.previousScroll?.rect) {

                switch(scroll.current.direction) {
                case .top:
                    if(range.location  <= reqCount) {
                        if !isNextCallLocked {
                            self.scrollHandler(scroll.current)
                        }
                        self.previousScroll = scroll.current
                    }
                case .bottom:
                    if(self.count - (range.location + range.length) <= reqCount) {
                        if !isNextCallLocked {
                            self.scrollHandler(scroll.current)
                        }
                        self.previousScroll = scroll.current
                    }
                case .none:
                    if !isNextCallLocked {
                        self.scrollHandler(scroll.current)
                    }
                    self.previousScroll = scroll.current
                }
            }
            
        }
        
        for listener in self.scrollListeners {
            if !listener.dispatchWhenVisibleRangeUpdated || listener.first || !NSEqualRanges(scroll.current.visibleRows, listener.dispatchRange) {
                listener.handler(scroll.current)
                listener.first = false
                listener.dispatchRange = scroll.current.visibleRows
            }
        }
        
        if self.needUpdateVisibleAfterScroll {
            let range = self.visibleRows()
            for i in range.location ..< range.location + range.length {
                if let view = self.viewNecessary(at: i) {
                    view.updateMouse()
                }
            }
        }
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
        
        self.scrollDidLiveScrolling()
        
        
        var point = self.clipView.bounds.origin
        if let updateScrollPoint = updateScrollPoint {
            point = updateScrollPoint(point)
        }
        let position = ScrollPosition(NSMakeRect(point.x, point.y,contentView.documentRect.width, contentView.documentRect.height), .none, NSMakeRange(0, 0))
        
        self.scrollDidUpdate?(position)

    }
    
    open func scrollDidEndLiveScrolling() {
        liveScrolling = false
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
            
            NotificationCenter.default.addObserver(forName: NSScrollView.didEndLiveScrollNotification, object: self, queue: nil, using: { [weak self] _ in
                self?.scrollDidEndLiveScrolling()
            })
            
            NotificationCenter.default.addObserver(forName: NSScrollView.willStartLiveScrollNotification, object: self, queue: nil, using: { [weak self] _ in
                self?.scrollWillStartLiveScrolling()
            })
            
            NotificationCenter.default.addObserver(forName: NSScrollView.didLiveScrollNotification, object: self, queue: nil, using: { [weak self] _ in
                self?.scrollDidLiveScrolling()
            })
            

            NotificationCenter.default.addObserver(forName: NSScrollView.boundsDidChangeNotification, object: clipView, queue: nil, using: { [weak self] _ in
                CATransaction.begin()
                if self?.superview != nil {
                    self?.updateScroll()
                }
                CATransaction.commit()
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
                stickItem.table = self
                self.stickItem = stickItem
                if visible {
                    let vz = stickItem.viewClass() as! TableStickView.Type
                    stickView = vz.init(frame:NSMakeRect(0, 0, NSWidth(self.frame), stickItem.heightValue))
                    stickView!.header = true
                    stickView!.set(item: stickItem, animated: false)
                    stickView!.updateLayout(size: stickView!.frame.size, transition: .immediate)
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
    
    public func optionalItem(at:Int) -> TableRowItem? {
        return at < count && at >= 0 ? self.item(at: at) : nil
    }
    
    private var needsLayouItemsOnNextTransition:Bool = false
   
    public func layouItemsOnNextTransition() {
        needsLayouItemsOnNextTransition = true
    }
    public func layoutItems() {

        let visibleItems = self.visibleItems()
        
        self.beginTableUpdates()
        self.enumerateItems { item in
            _ = item.makeSize(frame.width, oldWidth: item.width)
            reloadData(row: item.index, animated: false)
            return true
        }
        self.endTableUpdates()
        
        
        self.saveScrollState(visibleItems)
        
        self.needsLayouItemsOnNextTransition = false
    }
    
    public override var _mouseDownCanMoveWindow: Bool {
        didSet {
            clipView._mouseDownCanMoveWindow = _mouseDownCanMoveWindow
            tableView._mouseDownCanMoveWindow = _mouseDownCanMoveWindow
        }
    }
    
    open override var mouseDownCanMoveWindow: Bool {
        return _mouseDownCanMoveWindow
    }
    
    private func saveScrollState(_ visibleItems: [(TableRowItem,CGFloat,CGFloat)]) -> Void {
        //
        if !visibleItems.isEmpty {
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
                    
                    self.clipView.updateBounds(to: NSMakePoint(0, y))
                   // reflectScrolledClipView(clipView)
                   // flashScrollers()
                    break
                }
            }
        }
    }
    
    func getScrollY(_ visibleItems: [(TableRowItem,CGFloat,CGFloat)]) -> CGFloat? {
        if !visibleItems.isEmpty {
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
                    
                    return y
                }
            }
        }
         return nil
    }

    
    private let stickTimeoutDisposable = MetaDisposable()
    private var previousStickMinY: CGFloat? = nil
    
    private var stickTopInset: CGFloat = 0
    public func updateStickInset(_ inset: CGFloat, animated: Bool) {
        if stickTopInset != inset {
            stickTopInset = inset
            updateStickAfterScroll(animated)
        }
    }
    
    
    public func updateStickAfterScroll(_ animated: Bool) -> Void {
        let visibleRect = self.tableView.visibleRect
        let range = self.tableView.rows(in: NSMakeRect(visibleRect.minX, visibleRect.minY, visibleRect.width, visibleRect.height - stickTopInset))
        
        if let stickClass = stickClass, !updating {
         //   if documentSize.height > frame.height {
                
                let flipped = tableView.isFlipped

                
                var index:Int = flipped ? range.location : range.location + range.length - 1
            
            
                
                let scrollInset = self.documentOffset.y - stickTopInset + (flipped ? 0 : frame.height)
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
                    
                    if someItem.singletonItem {
                        currentStick = someItem
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
                        let scrollerIndex = subviews.firstIndex(where: { $0 is NSScroller })
                        let stickViewIndex = subviews.firstIndex(where: { $0 is TableStickView })
                        if let scrollerIndex = scrollerIndex, stickViewIndex == nil || stickViewIndex! > scrollerIndex {
                            addSubview(stickView, positioned: .below, relativeTo: subviews[scrollerIndex])
                        }
                    }
                    
                    stickView?.setFrameSize(frame.width, someItem.heightValue)
                    let itemRect:NSRect = someItem.view?.visibleRect ?? NSZeroRect

                    if let item = stickItem, item.isKind(of: stickClass), let stickView = stickView {
                        let rect:NSRect = self.rectOf(item: item)
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
                        if scrollInset <= 0, item.singletonItem {
                            yTopOffset = abs(scrollInset)
                        }
                        
                        let updatedPoint = NSMakePoint(0, yTopOffset + stickTopInset)
                        if stickView.frame.origin != updatedPoint {
                            stickView._change(pos: updatedPoint, animated: animated)
                        }
                        stickView.header = abs(dif) <= item.heightValue
                        
                        if !firstTime {
                            let rows:[Int] = [tableView.row(at: NSMakePoint(0, min(scrollInset - stickView.frame.height, documentSize.height - stickView.frame.height))), tableView.row(at: NSMakePoint(0, scrollInset))]
                            var applied: Bool = false
                            for row in rows {
                                let row = min(max(0, row), list.count - 1)
                                if let dateItem = self.item(at: row) as? TableStickItem, let view = dateItem.view as? TableStickView {
                                    if documentOffset.y > (documentSize.height - frame.height) && !tableView.isFlipped {
                                        yTopOffset = -1
                                    }
                                    view.updateIsVisible(yTopOffset < 0 , animated: false)
                                    applied = true
                                }
                            }
                            if !applied {
                                self.enumerateVisibleViews(with: { view in
                                   (view as? TableStickView)?.updateIsVisible(true, animated: false)
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
                            stickView.isHidden = (documentOffset.y <= 0 && !item.singletonItem)// && !stickView.isAlwaysUp
                        } else {
                            stickView.isHidden = documentSize.height <= frame.height || documentOffset.y > (documentSize.height - frame.height)
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
                            stickView._change(pos: NSMakePoint(0, -stickView.frame.height), animated: animated, removeOnCompletion: false, completion: { [weak stickView] _ in
                                stickView?.removeFromSuperview()
                            })
                        } else {
                            stickView?.removeFromSuperview()
                        }
                    } else {
                        stickView?.setFrameOrigin(0, 0)
                        stickView?.header = true
                        stickView?.isHidden = true
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
        resetScroll()
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
            return self.list.firstIndex(of: it)
        }
        return nil
    }
    
    public func index(hash:AnyHashable) -> Int? {
        
        if let it = self.listhash[hash] {
            return it.index
        }
        
        return nil
    }
    
    fileprivate func startResorting(_ range: NSRange, _ offset: CGPoint) {
        guard let window = _window else {return}
        
        let point = tableView.convert(window.mouseLocationOutsideOfEventStream, from: nil)
        if range.length > 0, let controller = resortController, controller.canResort(range.location), let view = viewNecessary(at: range.location) {
            controller.resortRow = range.location
            controller.currentHoleIndex = range.location
            controller.resortView = view
            controller.startLocation = NSMakePoint(round(point.y), round(point.y))
            controller.startRowLocation = view.frame.origin.offsetBy(dx: 0, dy: round(offset.y))
            controller.start(range.location)
   
            view.frame = convert(view.frame, from: view.superview)
            
            
            
            addSubview(view)
            view.isHidden = false
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                guard let controller = self?.resortController, controller.isResorting else {return .rejected}
                self?.stopResorting()
                return .invoked
            }, with: self, for: .leftMouseUp, priority: .modal)
            
            var first: Bool = true
            
            window.set(mouseHandler: { [weak self] event -> KeyHandlerResult in
                if let controller = self?.resortController, let view = controller.resortView, let `self` = self {
                    
                    self.contentView.autoscroll(with: event)
                    
                    var point = self.tableView.convert(event.locationInWindow, from: nil)
                    point.x = 0
                    let difference = (controller.startLocation.y - point.y)
                
                    if view.superview != self {
                        view.frame = self.convert(view.frame, from: view.superview)
                        let item = self.item(at: range.location)
                        view.set(item: item, animated: false)
                        view.updateLayout(size: view.frame.size, transition: .immediate)
                        controller.resortView = view
                        self.addSubview(view)
                    }
                    view.isHidden = false
                    
                    var newPoint = NSMakePoint(view.frame.minX, max(controller.startRowLocation.y - difference, 0))
                    newPoint.y -= self.documentOffset.y //self.convert(newPoint, from: self.tableView)
                    newPoint = NSMakePoint(round(newPoint.x), round(newPoint.y))
                    if first {
                        view.layer?.animatePosition(from: NSMakePoint(0, view.frame.minY - newPoint.y), to: .zero, duration: duration, timingFunction: .spring, removeOnCompletion: true, additive: true)
                    }
                    view.setFrameOrigin(newPoint)
                    first = false
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
        
        NSAnimationContext.current.duration = animation != .none ? duration : 0.0
        NSAnimationContext.current.timingFunction = animation == .none ? nil : CAMediaTimingFunction(name: .easeOut)
        if(redraw) {
            self.tableView.insertRows(at: IndexSet(integer: at), withAnimation: animation)
          //  self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: at))
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
            NSAnimationContext.current.timingFunction = nil
        }
        tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
        let item = self.item(at: row)
        let height = item.heightValue
        
        let transition: ContainedViewLayoutTransition = animated ? .animated(duration: duration, curve: .easeOut) : .immediate
        if let view = item.view {
            view.set(item: item, animated: animated)
            view.updateLayout(size: NSMakeSize(frame.width, height), transition: transition)
            transition.updateFrame(view: view, frame: CGRect(origin: view.frame.origin, size: NSMakeSize(frame.width, height)))
        }
    }
    
    
    
    public func reloadData(row:Int, animated:Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false) -> Void {
        if let view = self.viewNecessary(at: row) {
            let item = self.item(at: row)
            
            if view.isKind(of: item.viewClass()) && !presentAsNew {
                
                let height:CGFloat = item.heightValue
                let width:CGFloat = self is HorizontalTableView ? item.width : frame.width

                let rect = CGRect(origin: view.frame.origin, size: CGSize(width: width, height: height))
                
                let animated = animated && view.canAnimateUpdate(item)

                
                let transition: ContainedViewLayoutTransition = animated ? .animated(duration: duration, curve: .easeOut) : .immediate
                
                
                view.set(item: item, animated: animated)
                view.updateLayout(size: rect.size, transition: transition)
                transition.updateFrame(view: view, frame: rect)
                NSAnimationContext.current.duration = animated ? duration : 0.0
                NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.tableView.beginUpdates()
                self.tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: row))
                self.tableView.endUpdates()
                
                return
            }
        }
        if let _ = self.optionalItem(at: row) {
            NSAnimationContext.current.duration = animated ? duration : 0.0
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.tableView.beginUpdates()
            self.tableView.removeRows(at: IndexSet(integer: row), withAnimation: animated ? options : [.none])
            self.tableView.insertRows(at: IndexSet(integer: row), withAnimation: animated ? options : [.none])
            self.tableView.endUpdates()

        }
    }
    
    fileprivate func reloadHeightItems() {
        beginTableUpdates()
        self.enumerateItems { item -> Bool in
            if item.reloadOnTableHeightChanged {
                self.reloadData(row: item.index)
            }
            return true
        }
        endTableUpdates()
    }
    
    public func fitToSize() {
    }
    
    
    public func moveItem(from:Int, to:Int, changeItem:TableRowItem? = nil, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        
        
        var item:TableRowItem = self.item(at:from);
        let animation: NSTableView.AnimationOptions = animation != .none ? item.animatable ? animation : .none : .none
        NSAnimationContext.current.duration = animation != .none ? duration : 0.0
        NSAnimationContext.current.timingFunction = animation != .none ? CAMediaTimingFunction(name: .easeOut) : nil

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
            self.reloadData(row: to)
        }
        
    }
    
    public func beginUpdates() -> Void {
        updating = true
        resetScroll(visibleRows())
        self.previousScroll = nil
    }
    
    public func endUpdates() -> Void {
        updating = false
        resetScroll(visibleRows())
        self.previousScroll = nil
    }
    
    public func rectOf(item:TableRowItem) -> NSRect {
        let rect = self.tableView.rect(ofRow: item.index)
        return CGRect(origin: CGPoint(x: round(rect.minX), y: round(rect.minY)), size: rect.size)
    }
    
    public func rectOf(index:Int) -> NSRect {
        if index >= 0 && index < list.count {
            return self.tableView.rect(ofRow: index)
        }
        return .zero
    }
    
    public func remove(at:Int, redraw:Bool = true, animation:NSTableView.AnimationOptions = .none) -> Void {
        if at < count {
            let item = self.list.remove(at: at);
            self.listhash.removeValue(forKey: item.stableId)
            
            viewNecessary(at: at)?.onRemove(animation)
                        
            item._index = nil

            let animation: NSTableView.AnimationOptions = animation != .none ? item.animatable ? animation : .none : .none
            NSAnimationContext.current.duration = animation == .none ? 0.0 : duration
            NSAnimationContext.current.timingFunction = animation == .none ? nil : CAMediaTimingFunction(name: .easeOut)

            if(redraw) {
                self.tableView.removeRows(at: IndexSet(integer:at), withAnimation: animation)
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
            self.scroll(to: .top(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), toVisible: true)
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
            self.scroll(to: .bottom(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: 0), inset: NSEdgeInsets(), toVisible: true)
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
            self.scroll(to: .top(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), toVisible: true)
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
            self.scroll(to: .bottom(id: hash, innerId: nil, animated: animated, focus: .init(focus: false), inset: previousInset), inset: NSEdgeInsets(), toVisible: true)
        }
    }
    
    
    public var isEmpty:Bool {
        
        if let emptyChecker = emptyChecker {
            return emptyChecker(self.list)
        }
        
        return self.list.isEmpty || (!tableView.isFlipped && list.count == 1)
    }
    
    public func reloadData(width: CGFloat? = nil) -> Void {
        self.beginTableUpdates()
        self.enumerateItems { item -> Bool in
            _ = item.makeSize(width ?? frame.width)
            self.reloadData(row: item.index)
            return true
        }
        self.endTableUpdates()
    }
    
    public func reloadHeight() {
        self.beginTableUpdates()
        for index in 0 ..< list.count {
            NSAnimationContext.current.duration = 0
            NSAnimationContext.current.timingFunction = nil
            tableView.noteHeightOfRows(withIndexesChanged: IndexSet(integer: index))
        }
        self.endTableUpdates()
//        self.tableView.tile()
    }
    
    public func item(at:Int) -> TableRowItem {
        return self.list[at]
    }
    
    public func visibleRows(_ insetHeight:CGFloat = 0) -> NSRange {
        //self.tableView.visibleRect
        var rect = NSMakeRect(0, documentOffset.y, self.tableView.visibleRect.width, self.tableView.visibleRect.height).insetBy(dx: 0, dy: -insetHeight)
        if insetHeight == 0, contentInsets.top > 0 {
            rect.size.height -= contentInsets.top
        }
        let range = self.tableView.rows(in: rect)
        return range
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
                    self.cancelHighlight()
                    item.prepare(true)
                    self.reloadData(row:item.index, animated: true)
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
                    self.reloadData(row:item.index, animated: true)
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
                self.reloadData(row:item.index, animated: true)
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
                self.reloadData(row: item.index, animated: true)
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
            if let item = item as? TableStickItem, item.singletonItem {
                view = TableRowView(frame: NSMakeRect(0, 0, frame.width, item.heightValue))
            } else {
                view = makeView(for: item)
            }
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
    private func makeView(for item: TableRowItem) -> TableRowView {
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
        view.updateLayout(size: view.frame.size, transition: .immediate)
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
    
   
    
    public func merge(with transition:TableUpdateTransition, appearAnimated: Bool = false) -> Void {
        self.merge(with: transition, forceApply: false, appearAnimated: appearAnimated)
    }
    
//    private var awaitingTransitions: [TableUpdateTransition] = []
    
    private var processedIds: Set<Int64> = Set()
    private var firstSearchAppear = true
    private var currentSearchState: SearchState?
    
    private func enqueueAwaitingIfNeeded() {
//        while !awaitingTransitions.isEmpty && !self.clipView.isAnimateScrolling {
//            self.merge(with: awaitingTransitions.remove(at: 0), forceApply: true, appearAnimated: false)
//        }
    }
    
    private func merge(with transition:TableUpdateTransition, forceApply: Bool, appearAnimated: Bool) -> Void {
        
        
        if processedIds.contains(transition.uniqueId)  {
            return
        }
        self.processedIds.insert(transition.uniqueId)
        
        assertOnMainThread()
        assert(!updating)
        
        if case .saveVisible = transition.state {
            clipView.cancelScrolling()
        }

        
        
        let oldEmpty = self.isEmpty
        
        self.beginUpdates()
        
        let documentOffset = self.documentOffset
        
        
        let visibleItems = self.visibleItems()
        let visibleRange = self.visibleRows()
        
        for (_, item) in list.enumerated() {
            item._index = nil
        }
        

        var inserted:[(TableRowItem, NSTableView.AnimationOptions)] = []
        var removed:[(Int, TableRowItem)] = []
        
                
        if transition.grouping && !transition.isEmpty, !transition.state.isNone {
            self.tableView.beginUpdates()
        }
        
        for rdx in transition.deleted.reversed() {
            let effect:NSTableView.AnimationOptions
            if case let .none(interface) = transition.state, interface != nil {
                effect = (visibleRange.indexIn(rdx) || !transition.animateVisibleOnly) ? .effectFade : .none
            } else {
                effect = transition.animated && (visibleRange.indexIn(rdx) || !transition.animateVisibleOnly) ? .effectFade : .none
            }
            if rdx < visibleRange.location {
                removed.append((rdx, item(at: rdx)))
            }
            self.remove(at: rdx, redraw: true, animation:effect)
        }
        
        for (i, item) in list.enumerated() {
            item._index = i
        }
        
        if transition.grouping && !transition.isEmpty, !transition.state.isNone {
            self.tableView.endUpdates()
        }
                

        if transition.grouping && !transition.isEmpty, !transition.state.isNone {
            self.tableView.beginUpdates()
        }
        
        for (idx, item) in transition.inserted {
            let effect:NSTableView.AnimationOptions
            if case let .none(interface) = transition.state, interface != nil {
                effect = (visibleRange.indexIn(idx) || !transition.animateVisibleOnly) ? .effectFade : .none
            } else {
                effect = transition.animated && (visibleRange.indexIn(idx) || !transition.animateVisibleOnly) ? .effectFade : .none
            }
            _ = self.insert(item: item, at:idx, redraw: true, animation: effect)

            if item.animatable {
                inserted.append((item, effect))
            }
        }
        
        for (i, item) in list.enumerated() {
            item._index = i
        }
        
        if transition.grouping && !transition.isEmpty, !transition.state.isNone {
            self.tableView.endUpdates()
        }
        
        
        for inserted in inserted {
            var accept: Bool = true
            let index = inserted.0.index
            
            let item: TableRowItem?
            
            if let current = removed.first(where: { $0.0 == index })?.1 {
                item = current
            } else if let current = transition.updated.first(where: { $0.0 == index })?.1 {
                item = current
            } else {
                item = nil
            }
            
            if let item = item {
                if object_getClassName(item) == object_getClassName(inserted.0) {
                    accept = false
                }
            }
            if case let .none(interface) = transition.state, interface != nil {
                accept = false
            }
            inserted.0.view?.onInsert(inserted.1, appearAnimated: appearAnimated && accept)
        }
                
        let state: TableScrollState
        
        if case .none = transition.state, !transition.deleted.isEmpty || !transition.inserted.isEmpty {
            state = transition.state
        } else {
            state = transition.state
        }
        
        
        func saveVisible(_ side: TableSavingSide) {

            self.clipView.cancelScrolling()
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
                
                var item = self.item(stableId: visible.0.stableId)
                if item == nil {
                    if let groupStableId = delegate?.findGroupStableId(for: visible.0.stableId) {
                        item = self.item(stableId: groupStableId)
                    }
                }
                if let item = item {
                    
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
                    self.clipView.updateBounds(to: NSMakePoint(0, y))
                    break
                }
            }
        }
        switch state {
        case let .none(animation):
            if !oldEmpty {
                let result = animation?.animate(table:self, documentOffset: documentOffset, added: inserted.map{ $0.0 }, removed: removed.map { $0.1 }, previousRange: visibleRange)
                if let result = result, result.isEmpty {
                    if !transition.isEmpty, contentView.bounds.minY > 0 {
                        saveVisible(.lower)
                    }
                }
            }
        case .bottom, .top, .center:
            self.scroll(to: transition.state, previousDocumentOffset: documentOffset)
        case .up, .down, .upOffset:
            self.scroll(to: transition.state, previousDocumentOffset: documentOffset)
        case let .saveVisible(side):
            saveVisible(side)
        }
              
        var nonAnimatedItems: [(Int, TableRowItem)] = []
        var animatedItems: [(Int, TableRowItem)] = []

        var animated: Bool = transition.animated
        if case let .none(interface) = transition.state, interface != nil {
            animated = true
        }
        for (index,item) in transition.updated {
            let animated: Bool
            animated = (visibleRange.indexIn(index) || !transition.animateVisibleOnly)
            if animated {
                animatedItems.append((index, item))
            } else {
                nonAnimatedItems.append((index, item))
            }
        }
        
        
        
        let visible = self.visibleItems()

        self.beginTableUpdates()
        for (index, item) in nonAnimatedItems {
            replace(item: item, at: index, animated: false)
        }
        self.endTableUpdates()
        if !tableView.isFlipped, case .none = transition.state {
            saveScrollState(visible)
        }

       // self.beginTableUpdates()
        for (index, item) in animatedItems {
            replace(item: item, at: index, animated: true)
        }
       
        
        self.endUpdates()
        
        
        
        self.updatedItems?(self.list)
        
//        self.reflectScrolledClipView(self.clipView)
//        self.tableView.tile()

        if oldEmpty != isEmpty || first {
            updateEmpties(animated: !first)
        }
        
        if let searchState = transition.searchState {
            
//            if let scrollView = self.enclosingScrollView {
//                scrollView.tile()
//                scrollView.reflectScrolledClipView(scrollView.contentView)
//            }
//
            if self.searchView == nil {
                self.searchView = TableSearchView(frame: NSMakeRect(0, -50, frame.width, 50))
                addSubview(self.searchView!)
            }
            guard let searchView = self.searchView else {
                return
            }
            switch searchState {
            case let .none(updateState):
                searchView.change(pos: NSMakePoint(0, -searchView.frame.height), animated: true)
                searchView.searchView.cancel(true)
                
                searchView.searchView.searchInteractions = SearchInteractions({ state, _ in
                    updateState(state)
                }, { state in
                    updateState(state)
                })
                updateState(nil)
                firstSearchAppear = true
            case let .visible(data):
                searchView.change(pos: NSZeroPoint, animated: true)
                if firstSearchAppear {
                    searchView.applySearchResponder()
                }
                firstSearchAppear = false
                searchView.updateDatas(data)
                
                searchView.searchView.searchInteractions = SearchInteractions({ state, _ in
                    data.updateState(state)
                }, { state in
                    data.updateState(state)
                })
                
                let searchState: SearchState = .init(state: searchView.searchView.state, request: searchView.searchView.query)
                
                if searchState != self.currentSearchState {
                    self.currentSearchState = searchState
                    data.updateState(searchState)
                }
            }
        } else {
            self.searchView?.removeFromSuperview()
            self.searchView = nil
        }
        
        first = false
        performScrollEvent(transition.animated)
        updateStickAfterScroll(transition.animated)
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
                        emptyView.layer?.animateAlpha(from: 0, to: 1, duration: duration)
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
                        emptyView.layer?.animateAlpha(from: 1, to: 0, duration: duration, removeOnCompletion: false, completion: { [weak emptyView] completed in
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
            let prev = list[index]
            listhash.removeValue(forKey: list[index].stableId)
            list[index] = item
            listhash[item.stableId] = item
            item.table = self
            item._index = index
            reloadData(row: index, animated: animated, presentAsNew: prev.identifier != item.identifier)
        }
    }

    public func contentInteractionView(for stableId: AnyHashable, animateIn: Bool) -> NSView? {
        
        if let supplyment = supplyment {
            return supplyment.contentInteractionView(for: stableId, animateIn: animateIn)
        }
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
        
        if let supplyment = supplyment {
            return supplyment.interactionControllerDidFinishAnimation(interactive: interactive, for: stableId)
        }
        
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
        
        if let supplyment = supplyment {
            return supplyment.addAccesoryOnCopiedView(for: stableId, view: view)
        }
        
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
        
        if let supplyment = supplyment {
            return supplyment.applyTimebase(for: stableId, timebase: timebase)
        }
        
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
    
    func longAction(index: Int) {
        if self.count > index {
            _ = self.delegate?.longSelect(row: index, item: self.list[index])
        }
    }
    
    public override func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        
        
        if animated {

            if !tableView.isFlipped {
                
                if self.frame.size != size {
                    let bounds = self.layer?.presentation()?.bounds ?? self.bounds
                    let y = (size.height - bounds.height)

                    self.layer?.animateBoundsOriginYAdditive(from: -y, to: 0, duration: duration)

                    
                    if let layer = contentView.layer {
                        let animation = layer.makeAnimation(from: NSNumber(value: -y), to: NSNumber(value: 0), keyPath: "bounds.size.height", timingFunction: timingFunction, duration: duration, additive: true)
                        layer.add(animation, forKey: "height")
                    }
                }
                                
                self.updateStickAfterScroll(animated)
                return
            }
        }
        
        super.change(size: size, animated: animated, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        self.tile()
        self.updateStickAfterScroll(animated)
    }
    
    
    
    public func scroll(to state:TableScrollState, inset:NSEdgeInsets = NSEdgeInsets(), timingFunction: CAMediaTimingFunctionName = .spring, toVisible:Bool = false, ignoreLayerAnimation: Bool = false, previousDocumentOffset: CGPoint? = nil, completion: @escaping(Bool)->Void = { _ in }) {
        
        var rowRect:NSRect = bounds
        let documentOffset = previousDocumentOffset
        
        let findItem:(AnyHashable)->TableRowItem? = { [weak self] stableId in
            var item: TableRowItem? = self?.item(stableId: stableId)
            if item == nil {
                if let groupStableId = self?.delegate?.findGroupStableId(for: stableId) {
                    item = self?.item(stableId: groupStableId)
                }
            }
            return item
        }
        
        
        
        var item:TableRowItem?
        var animate:Bool = false
        var focus: TableScrollFocus = .init(focus: false)
        var relativeInset: CGFloat = 0
        var innerId: AnyHashable? = nil
        var addition: CGFloat = 0
        switch state {
        case let .center(stableId, _innerId, _animate, _focus, _inset):
            item = findItem(stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
        case let .bottom(stableId, _innerId, _animate, _focus, _inset):
            item = findItem(stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
        case let .top(stableId, _innerId, _animate, _focus, _inset):
            item = findItem(stableId)
            animate = _animate
            relativeInset = _inset
            focus = _focus
            innerId = _innerId
            addition = contentInsets.top
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
                rowRect.origin = NSMakePoint(0,  -contentInsets.top)
            }
            relativeInset = offset
        default:
            fatalError("for scroll to item, you can use only .top, center, .bottom enumeration")
        }
        
        let bottomInset = self.bottomInset != 0 ? (self.bottomInset) : 0
        let height:CGFloat = self is HorizontalTableView ? frame.width : frame.height

        let documentHeight = documentSize.height
        
        if documentHeight < height {
            completion(false)
            return
        }
        
        if let item = item {
            rowRect = self.rectOf(item: item)
            var state = state
            if case let .center(id, innerId, animated, focus, inset) = state, rowRect.height > height {
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
                    rowRect.origin.y -= (height - rowRect.height) - bottomInset - contentInsets.top
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
                        view.focusAnimation(innerId, text: focus.string)
                        focus.action?(view.interactableView)
                    }
                    completion(true)
                    return
                }
            }
        }
        
        rowRect.origin.y = round(min(max(rowRect.minY + relativeInset, (!tableView.isFlipped ? 0 : -contentInsets.top)), documentSize.height - height) + inset.top)
        
        if self.tableView.isFlipped {
            rowRect.origin.y = min(rowRect.origin.y, documentSize.height - clipView.bounds.height)
        }
        if clipView.bounds.minY != rowRect.minY {
            
            var applied = false
            let scrollListener = TableScrollListener({ [weak self, weak item] position in
                if let item = item, !applied {
                    DispatchQueue.main.async {
                        if let view = self?.viewNecessary(at: item.index), view.visibleRect.height > 10 {
                            applied = true
                            if focus.focus {
                                view.focusAnimation(innerId, text: focus.string)
                                focus.action?(view.interactableView)
                            }
                        }
                    }
                }
            })
            
            addScroll(listener: scrollListener)
            
            let bounds = NSMakeRect(0, rowRect.minY + addition, clipView.bounds.width, clipView.bounds.height)
                        
            if animate {
                clipView.scroll(to: bounds.origin, animated: animate, completion: { [weak self] completed in
                    if let `self` = self {
                        scrollListener.handler(self.scrollPosition().current)
                        self.removeScroll(listener: scrollListener)
                        completion(completed)
                        self.scrollDidChangedBounds()
                    }
                })
            } else {
                self.clipView.updateBounds(to: bounds.origin)
                removeScroll(listener: scrollListener)
                scrollListener.handler(self.scrollPosition().current)
            }
        } else {
            if let item = item  {
                if focus.focus, let view = viewNecessary(at: item.index) {
                    view.focusAnimation(innerId, text: focus.string)
                    focus.action?(view.interactableView)
                }
                completion(true)
            } else {
                if let documentOffset = documentOffset, documentOffset != clipView.documentOffset {
                    clipView.scroll(to: documentOffset, animated: false)
                    clipView.scroll(to: rowRect.origin, animated: animate)
                }
            }
        }

    }
    
    open override func accessibilityParent() -> Any? {
        return nil
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        let visible = visibleItems()
        let oldWidth = frame.width
        let oldHeight = frame.height
        super.setFrameSize(newSize)
       
        if newSize.width > 0 || newSize.height > 0 {
            if oldWidth != frame.width, newSize.width > 0 && newSize.height > 0 {
                self.layoutIfNeeded(with: self.visibleRows(), oldWidth: oldWidth)
            } else if oldHeight != frame.height {
                self.reloadHeightItems()
            }
        }
        
        //updateStickAfterScroll(false)
        if oldWidth != newSize.width, !inLiveResize && newSize.width > 0 && newSize.height > 0 {
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
    
    public func enumerateVisibleItems(reversed: Bool = false, inset: CGFloat = 0, with callback:(TableRowItem)->Bool) {
        let visible = visibleRows(inset)
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
        self.resetScroll(visibleRows())
        //NotificationCenter.default.post(name: NSView.boundsDidChangeNotification, object: self.contentView)
    }
    
    deinit {
        mergeDisposable.dispose()
        stickTimeoutDisposable.dispose()
    }
    
    
    public func sizeToFitIfNeeded() {
        clipView.documentView?.setFrameSize(NSMakeSize(tableView.frame.width, min(tableView.frame.height, listHeight)))
        clipView.needsLayout = true
    }
    
}
