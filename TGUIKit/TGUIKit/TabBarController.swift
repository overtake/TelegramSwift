//
//  TabBarController.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public class TabBarController: ViewController, TabViewDelegate {

    private var tabView:TabBarView?
    
    private weak var current:ViewController? {
        didSet {
            current?.navigationController = self.navigationController
        }
    }
    
    public override func loadView() {
        super.loadView()
        tabView = TabBarView.init(frame: NSMakeRect(0, NSHeight(self.bounds) - 50, NSWidth(self.bounds), 50))
        tabView?.delegate = self
        tabView?.autoresizingMask = [NSAutoresizingMaskOptions.viewWidthSizable, NSAutoresizingMaskOptions.viewMaxYMargin,NSAutoresizingMaskOptions.viewMinYMargin]
        addSubview(tabView!)
    }
    
    public func didChange(selected item: TabItem, index: Int) {
        
        if let tabView = tabView {
            if let current = current {
                current.viewWillDisappear(false)
                current.view.removeFromSuperview()
                current.viewDidDisappear(false)
            }
            item.controller._frameRect = NSMakeRect(0, 0, bounds.width, bounds.height - tabView.frame.height)
            item.controller.view.frame = item.controller._frameRect
            item.controller.viewWillAppear(false)
            addSubview(item.controller.view)
            item.controller.viewDidAppear(false)
            
            current = item.controller
            
        }
        
    }
    
    public func select(index:Int) -> Void {
        tabView?.setSelectedIndex(index, respondToDelegate: true)
    }
    
    public func add(tab:TabItem) -> Void {
        self.tabView?.addTab(tab)
    }
    
}
