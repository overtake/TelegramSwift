//
//  TableRowItem.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

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
    
    open private(set) var height:CGFloat = 60;
    
    
    public var size:NSSize  {
        return NSMakeSize(width, height)
    }
    
    public var oldWidth:CGFloat = 0
    
    public var width:CGFloat  {
        if let table = table {
            return table.frame.width
        } else {
            return initialSize.width
        }
    }
    
    open var stableId:AnyHashable {
        return 0
    }
    
    public var index:Int {
        get {
            if let table = table, let index = table.index(of:self)  {
                return index
            } else {
                return -1
            }
        }
        
    }
    
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
    
    
    open func menuItems(in location: NSPoint) -> Signal<[ContextMenuItem], Void> {
        return .single([])
    }
    
    public func redraw()->Void {
        if index != -1 {
            table?.reloadData(row: index)
        }
    }
    
    public var isSelected:Bool {
        if let table = table {
            return table.isSelected(self)
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
    
    open func makeSize(_ width:CGFloat = CGFloat.greatestFiniteMagnitude, oldWidth:CGFloat = 0) -> Bool {
        self.oldWidth = width
        return true;
    }
}
