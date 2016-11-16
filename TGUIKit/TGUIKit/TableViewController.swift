//
//  TableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableViewController: ViewController {

    private(set) public var tableView:TableView!
    
    override open func loadView() {
        super.loadView()
        
        tableView = TableView(frame:bounds)
        addSubview(tableView)
        
        viewDidLoad()
    }
    
    open override func viewDidLoad() {
        
    }
    
    override open var enableBack: Bool {
        return true
    }
    
}
