//
//  TableViewController.swift
//  TGUIKit
//
//  Created by keepcoder on 15/11/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

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

public class TableSignaledViewController : TableViewController {
    private let signal:Signal<TableUpdateTransition, Void>
    init(_ signal:Signal<TableUpdateTransition, Void>) {
        self.signal = signal
        super.init()
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        genericView.merge(with: signal)
    }
}
