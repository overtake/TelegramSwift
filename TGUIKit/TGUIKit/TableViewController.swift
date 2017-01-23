//
//  TableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableViewController: GenericViewController<TableView>, TableViewDelegate {


    open override func loadView() {
        super.loadView()
        genericView.delegate = self
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    
    open func selectionDidChange(row:Int, item:TableRowItem, byClick:Bool, isNew:Bool) -> Void {
       
    }
    open func selectionWillChange(row:Int, item:TableRowItem) -> Bool {
        return false
    }
    open func isSelectable(row:Int, item:TableRowItem) -> Bool {
        return false
    }

    
    override open var enableBack: Bool {
        return true
    }
    
}
