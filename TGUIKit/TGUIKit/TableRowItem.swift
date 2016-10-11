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
    public weak var table:TableView?
    
    open private(set) var height:CGFloat = 60;
    
    
    public var size:NSSize  {
        return NSMakeSize(NSWidth(self.table!.frame), height)
    }
    
    open var stableId:Int64 {
        return Int64(0)
    }
    
    public  var index:Int {
        get {
            return self.table!.index(of:self)!;
        }

    }
    
    public init(_ table:TableView) {
        self.table = table
    }
    
    open func prepare(_ selected:Bool) {
        
    }
    
   
    open func menuItems() -> [ContextMenuItem]? {
        
        return [ContextMenuItem("item", handler: { 
            
        })];
        
    }
    
    
    
 
    public var isSelected:Bool {
        return self.table!.isSelected(self)
    }
    
    open func viewClass() ->AnyClass {
        return TableRowView.self;
    }
    
    open func makeSize(_ width:CGFloat = CGFloat.greatestFiniteMagnitude) -> Bool {
        return true;
    }
}
