//
//  TableRowItem.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKit

open class TableRowItem: NSObject {
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
    
    open var instantlyResize:Bool {
        return false
    }
    open var reloadOnTableHeightChanged: Bool {
        return false
    }
    
    open private(set) var height:CGFloat = 60;
    
    
    public var size:NSSize  {
        return NSMakeSize(width, height)
    }
    
    public var oldWidth:CGFloat = 0
    
    open var width:CGFloat  {
        return oldWidth
    }
    
    open var stableId:AnyHashable {
        return 0
    }
    
    open func copyAndUpdate(animated: Bool) {
        
    }
    
    open var index:Int {
        if let _index = _index {
            return _index
        } else if let table = table, let index = table.index(of:self) {
            return index
        } else {
            return -1
        }
    }

    
    internal(set) var _index:Int? = nil
    
    public init(_ initialSize:NSSize) {
        self.initialSize = initialSize
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
    
    
    open func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], NoError> {
        return .single([])
    }
    
    public func redraw(animated: Bool = false, options: NSTableView.AnimationOptions = .effectFade, presentAsNew: Bool = false)->Void {
        if index != -1 {
            table?.reloadData(row: index, animated: animated, options: options, presentAsNew: presentAsNew)
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
    
    open func makeSize(_ width:CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth:CGFloat = 0) -> Bool {
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
        return _isAutohidden ? 1.0 : self.height
    }
}
