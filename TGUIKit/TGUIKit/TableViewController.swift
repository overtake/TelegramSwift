//
//  TableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

open class TableViewController: GenericViewController<TableView> {


    override open func loadView() {
        super.loadView()
        viewDidLoad()
    }
    
    open override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override open var enableBack: Bool {
        return true
    }
    
}
