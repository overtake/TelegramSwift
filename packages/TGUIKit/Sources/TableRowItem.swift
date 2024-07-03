//
//  TableRowItem.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

open class TableRowItem: NSObject, Comparable, Identifiable {
    
    public static func < (lhs: TableRowItem, rhs: TableRowItem) -> Bool {
        return lhs.index < rhs.index
    }
    
    open override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? TableRowItem {
            return self.stableId == object.stableId
        } else {
            return false
        }
    }
    
    public weak var table:TableView? {
        didSet {
            tableViewDidUpdated()
        }
    }
    public let initialSize:NSSize
    
    open func tableViewDidUpdated() {
        
    }
    
    open var canBeAnchor: Bool {
        return true
    }
    
    open var isUniqueView: Bool {
        return false
    }
    
    open var animatable:Bool {
        return true
    }
    
    open var ignoreAtInitialization: Bool {
        return false
    }
    
    open var instantlyResize:Bool {
        return false
    }
    open var reloadOnTableHeightChanged: Bool {
        return false
    }
    
    open private(set) var height:CGFloat = 60;
    
    open var backdorColor: NSColor {
        return presentation.colors.background
    }
    open var borderColor: NSColor {
        return presentation.colors.border
    }
    
    public var size:NSSize  {
        return NSMakeSize(width, height)
    }
    
    public var oldWidth:CGFloat = 0
    
    private var _stableIdValue: AnyHashable = 0
    
    open var width:CGFloat  {
        if Thread.isMainThread, let table = table, table.frame.width > 0 {
            return table.frame.width
        } else if oldWidth == 0 {
            return initialSize.width
        }
        return oldWidth
    }
    
    open var stableId:AnyHashable {
        return _stableIdValue
    }
    
    open func copyAndUpdate(animated: Bool) {
        
    }
    
    open var index:Int {
        if let _index = _index {
            return _index
        } else {
            return -1
        }
    }
    internal var origin: NSPoint = .zero

    
    public var _index:Int? = nil
    var _yPosition:CGFloat? = nil

    
    public init(_ initialSize:NSSize) {
        self.initialSize = initialSize
    }
    
    public init(_ initialSize:NSSize, stableId: AnyHashable) {
        self.initialSize = initialSize
        _stableIdValue = stableId
    }
    
    open func prepare(_ selected:Bool) {
        
    }
    
    open var isVisible: Bool {
        if let table = table {
            let visible = table.visibleRows()
            return visible.indexIn(index)
        }
        return false
    }
    
    open var isLegacyMenu: Bool {
        return false
    }
    open var menuPresentation: AppMenu.Presentation {
        return .current(presentation.colors)
    }
    
    public var frame: NSRect {
        if let table = table {
            return table.rectOf(item: self)
        }
        return .zero
    }
    
    open var menuAdditionView: Signal<Window?, NoError> {
        return .single(nil)
    }
    
    open func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single([])
    }
    
    public func redraw(animated: Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false)->Void {
        if index != -1, let table = table {
            assert(!table.isUpdating)
            table.reloadData(row: index, animated: animated, options: options, presentAsNew: presentAsNew)
        }
    }
    public func noteHeightOfRow(animated: Bool = false) {
        if self.index != -1, let table = self.table {
            table.noteHeightOfRow(self.index, animated)
        }
    }
    
    public var isSelected:Bool {
        if let table = table {
            return table.isSelected(self)
        } else {
            return false
        }
    }
    public var isHighlighted: Bool {
        if let table = table {
            return table.isHighlighted(self)
        } else {
            return false
        }
    }
    
    open var isLast: Bool {
        return table?.lastItem == self
    }
    
    open func canMultiselectTextIn(_ location: NSPoint) -> Bool {
        if let view = view {
            return view.canMultiselectTextIn(location)
        }
        return false
    }
    
    open var identifier:String {
        return NSStringFromClass(viewClass())
    }
    
    open func viewClass() ->AnyClass {
        return TableRowView.self;
    }
    
    open var layoutSize: NSSize {
        return NSZeroSize
    }
    
    open var view: TableRowView? {
        assertOnMainThread()
        if let table = table {
            return table.viewNecessary(at: index)
        }
        return nil
    }
    
    open var viewNecessary: TableRowView? {
        assertOnMainThread()
        if let table = table {
            return table.viewNecessary(at: index, makeIfNecessary: true)
        }
        return nil
    }
    
    @discardableResult open func makeSize(_ width:CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth:CGFloat = 0) -> Bool {
        self.oldWidth = width
        return true;
    }
    
    public private(set) var _isAutohidden: Bool = false
    public var isAutohidden: Bool {
        return _isAutohidden
    }
    public func hideItem(animated: Bool, reload: Bool = true, options: NSTableView.AnimationOptions = .slideUp, presentAsNew: Bool = true) {
        _isAutohidden = true
        if reload {
            redraw(animated: animated, options: options, presentAsNew: presentAsNew)
        }
    }
    public func unhideItem(animated: Bool, reload: Bool = true, options: NSTableView.AnimationOptions = .slideDown, presentAsNew: Bool = true) {
        _isAutohidden = false
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .drawCompleted)
        if reload {
            redraw(animated: animated, options: .slideDown, presentAsNew: true)
        }
    }
    
    internal var heightValue: CGFloat {
        var height = self.height
        if height.isInfinite || height.isNaN {
            height = 1
        }
        return ceil(_isAutohidden ? 1.0 : height)
    }
}
