//
//  TabBarController.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private class TabBarViewController : View {
    let tabView:TabBarView

    
    required init(frame frameRect: NSRect) {
        tabView = TabBarView(frame: NSMakeRect(0, frameRect.height - 50, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(tabView)
    }
    
    override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        self.background = presentation.colors.background
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    override func layout() {
        super.layout()
        tabView.frame = NSMakeRect(0, frame.height - 50, frame.width, 50)
    }
}

public class TabBarController: ViewController, TabViewDelegate {

    
    public var didChangedIndex:(Int)->Void = {_ in}
    
    public weak var current:ViewController? {
        didSet {
            current?.navigationController = self.navigationController
        }
    }
    
    private var genericView:TabBarViewController {
        return view as! TabBarViewController
    }
    
    public override func viewClass() -> AnyClass {
        return TabBarViewController.self
    }
    
    public override func updateLocalizationAndTheme() {
        super.updateLocalizationAndTheme()
        genericView.tabView.enumerateItems({ item in
            if item.controller.isLoaded() {
                item.controller.updateLocalizationAndTheme()
            }
            return false
        })
    }
    
    public override func loadView() {
        super.loadView()
        genericView.tabView.delegate = self
        genericView.autoresizingMask = []
    }
    
    public func didChange(selected item: TabItem, index: Int) {
        
        if current != item.controller {
            if let current = current {
                current.window?.makeFirstResponder(nil)
                current.viewWillDisappear(false)
                current.view.removeFromSuperview()
                current.viewDidDisappear(false)
            }
            item.controller._frameRect = NSMakeRect(0, 0, bounds.width, bounds.height - genericView.tabView.frame.height)
            item.controller.view.frame = item.controller._frameRect
            item.controller.viewWillAppear(false)
            view.addSubview(item.controller.view)
            item.controller.viewDidAppear(false)
            current = item.controller
            didChangedIndex(index)
        }
    }
    
    public override func scrollup() {
        current?.scrollup()
    }
    
    public func hideTabView(_ hide:Bool) {
        genericView.tabView.isHidden = hide
        current?.view.frame = hide ? bounds : NSMakeRect(0, 0, bounds.width, bounds.height - genericView.tabView.frame.height)
        
    }
    
    public func select(index:Int) -> Void {
        genericView.tabView.setSelectedIndex(index, respondToDelegate: true)
    }
    
    public func add(tab:TabItem) -> Void {
        genericView.tabView.addTab(tab)
    }
    public func tab(at index:Int) -> TabItem {
        return genericView.tabView.tab(at: index)
    }
    public func replace(tab: TabItem, at index:Int) -> Void {
        genericView.tabView.replaceTab(tab, at: index)
    }
    public func insert(tab: TabItem, at index: Int) -> Void {
        genericView.tabView.insertTab(tab, at: index)
    }
    public func remove(at index: Int) -> Void {
        genericView.tabView.removeTab(at: index)
    }
    public var isEmpty:Bool {
        return genericView.tabView.isEmpty
    }
    
}
