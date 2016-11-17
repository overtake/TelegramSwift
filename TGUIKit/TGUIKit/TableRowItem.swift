//
//  TableRowItem.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import TelegramCoreMac
open class TableRowItem: NSObject,Identifiable {
    public weak var table:TableView? {
        didSet {
            tableViewDidUpdated()
        }
    }
    public let initialSize:NSSize

    open func tableViewDidUpdated() {
        
    }
    
    open private(set) var height:CGFloat = 60;
    
    
    public var size:NSSize  {
        return NSMakeSize(width, height)
    }
    
    public var width:CGFloat  {
        if let table = table {
            return table.frame.width
        } else {
            return initialSize.width
        }
    }
    
    open var stableId:Int64 {
        return Int64(0)
    }
    
    public var index:Int {
        get {
            if let table = table {
                return table.index(of:self)!;
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
    
   
    open func menuItems() -> [ContextMenuItem]? {
        
        return [ContextMenuItem("item", handler: { 
            
        })];
        
    }
    
    public func redraw()->Void {
        table?.reloadData(row: index)
    }
 
    public var isSelected:Bool {
        if let table = table {
            return table.isSelected(self)
        } else {
            return false
        }
    }
    
    open func viewClass() ->AnyClass {
        return TableRowView.self;
    }
    
    open func makeSize(_ width:CGFloat = CGFloat.greatestFiniteMagnitude) -> Bool {
        return true;
    }
}
