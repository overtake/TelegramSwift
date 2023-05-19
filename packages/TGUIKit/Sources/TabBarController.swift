//
//  TabBarController.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import AppKit

private class TabBarViewController : View {
    let tabView:TabBarView

    
    required init(frame frameRect: NSRect) {
        tabView = TabBarView(frame: NSMakeRect(0, frameRect.height - 50, frameRect.width, 50))
        super.init(frame: frameRect)
        addSubview(tabView)
    }
    
    override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        self.background = presentation.colors.background
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
    }
    
    func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        for subview in subviews {
            if let subview = subview as? TabBarView {
                transition.updateFrame(view: subview, frame: NSMakeRect(0, frame.height - 50, frame.width, 50))
            } else {
                if tabView.isHidden {
                    transition.updateFrame(view: subview, frame: bounds)
                } else {
                    transition.updateFrame(view: subview, frame: NSMakeRect(0, 0, frame.width, frame.height - tabView.frame.height))
                }
            }
        }
    }
    
    override func layout() {
        super.layout()
        updateFrame(frame, transition: .immediate)
    }
}

public class TabBarController: ViewController, TabViewDelegate {

    
    public var didChangedIndex:(Int)->Void = {_ in}
    
    public weak var current:ViewController? {
        didSet {
            current?.navigationController = self.navigationController
        }
    }
    
    public override var navigationController: NavigationViewController? {
        didSet {
            current?.navigationController = self.navigationController
        }
    }
    
    public override var redirectUserInterfaceCalls: Bool {
        return true
    }
    
    private var genericView:TabBarViewController {
        return view as! TabBarViewController
    }
    
    public override func viewClass() -> AnyClass {
        return TabBarViewController.self
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        super.updateLocalizationAndTheme(theme: theme)
        genericView.tabView.enumerateItems({ item in
            if item.controller.isLoaded() {
                item.controller.updateLocalizationAndTheme(theme: theme)
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
                _ = current.window?.makeFirstResponder(nil)
                current.viewWillDisappear(false)
                current.view.removeFromSuperview()
                current.viewDidDisappear(false)
            }
            item.controller._frameRect = NSMakeRect(0, 0, bounds.width, bounds.height - genericView.tabView.frame.height)
            item.controller.view.frame = item.controller._frameRect
            item.controller.viewWillAppear(false)
            view.addSubview(item.controller.view, positioned: .below, relativeTo: genericView.tabView)
            item.controller.viewDidAppear(false)
            current = item.controller
            didChangedIndex(index)
        }
    }
    
    public func scrollup() {
        current?.scrollup()
    }
    
    public func control(for index: Int) -> Control {
        return self.genericView.tabView.control(for: index)
    }
    
    public func hideTabView(_ hide:Bool) {
        genericView.tabView.isHidden = hide
        current?.view.frame = hide ? bounds : NSMakeRect(0, 0, bounds.width, bounds.height - genericView.tabView.frame.height)
        
    }
    
    public override func updateFrame(_ frame: NSRect, transition: ContainedViewLayoutTransition) {
        super.updateFrame(frame, transition: transition)
        self.genericView.updateFrame(frame, transition: transition)
    }
    
    public func select(index:Int) -> Void {
        if index != self.genericView.tabView.selectedIndex {
            genericView.tabView.setSelectedIndex(index, respondToDelegate: true, animated: false)
        }
    }
    
    public var count: Int {
        return genericView.tabView.count
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
    public func showTooltip(text: String, for index: Int) -> Void {
        genericView.tabView.showTooltip(text: text, for: index)
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.current?.viewWillAppear(animated)
    }
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.current?.viewDidAppear(animated)
    }
    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.current?.viewWillDisappear(animated)
    }
    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.current?.viewDidDisappear(animated)
    }
}
