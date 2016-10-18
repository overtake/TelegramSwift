//
//  TabBarView.swift
//  TGUIKit
//
//  Created by keepcoder on 27/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa


public protocol TabViewDelegate : class {
    func didChange(selected item:TabItem, index:Int)
}

public class TabBarView: View {

    private var tabs:[TabItem] = []
    public private(set) var selectedIndex:Int = 0
    
    public weak var delegate:TabViewDelegate?
    

    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ layer: CALayer, in ctx: CGContext) {
        super.draw(layer, in: ctx)
        
        ctx.setFillColor(NSColor.border.cgColor)
        
        ctx.fill(self.bounds)
    }
    
    func addTab(_ tab: TabItem) {
        self.tabs.append(tab)
        self.redraw()
    }
    
    func insertTab(_ tab: TabItem, at index: Int) {
        self.tabs.insert(tab, at: index)
        self.redraw()
    }
    
    func removeTab(_ tab: TabItem) {
        self.tabs.remove(at: self.tabs.index(of: tab)!)
        self.redraw()
    }
    
    func removeTab(at index: Int) {
        self.tabs.remove(at: index)
        self.redraw()
    }
    
    func redraw() {
        var width = NSWidth(self.bounds)
        var height = NSHeight(self.bounds) - .borderSize
        var defWidth = width / CGFloat(self.tabs.count)
        self.removeAllSubviews()
        var xOffset:CGFloat = 0
        let minY:CGFloat = 5
        
        
        for tab in tabs {
            var itemWidth = defWidth
            var view = View(frame: NSMakeRect(xOffset, .borderSize, itemWidth, height))
            var container = View(frame: view.bounds)
            view.autoresizingMask = [.viewMinXMargin, .viewMaxXMargin, .viewWidthSizable]
            view.autoresizesSubviews = true
            var imageView = ImageView(frame: NSMakeRect(0, 0, tab.image.backingSize.width, tab.image.backingSize.height))
            imageView.image = tab.image
            container.addSubview(imageView)
            container.setFrameSize(NSMakeSize(NSWidth(imageView.frame), NSHeight(container.frame)))
            view.addSubview(container)
           
            imageView.center()
            container.center()

            self.addSubview(view)
            xOffset += itemWidth
        }
        
        self.setSelectedIndex(self.selectedIndex, respondToDelegate: false)
    }
    
    
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        var width = NSWidth(self.bounds)
        var height = NSHeight(self.bounds) - .borderSize
        var defWidth = width / CGFloat( max(1, self.tabs.count) )
        var xOffset:CGFloat = 0
        
        var idx:Int = 0
        
        for subview in subviews {
            var w = idx == subviews.count - 1 ? defWidth - .borderSize : defWidth
            var child = subview.subviews[0]
            subview.frame = NSMakeRect(xOffset, .borderSize, w, height)
            child.center()
            xOffset += w
            
            idx += 1
        }
        
    }
    
    
    public func setSelectedIndex(_ selectedIndex: Int, respondToDelegate: Bool) {
        if selectedIndex > self.tabs.count || self.tabs.count == 0 {
            return
        }
        let deselectItem = self.tabs[self.selectedIndex]
        let deselectView = self.subviews[self.selectedIndex]
        
        var image:ImageView = deselectView.subviews[0].subviews[0] as! ImageView
        image.image = deselectItem.image
        self.selectedIndex = selectedIndex
        var selectItem = self.tabs[self.selectedIndex]
        var selectView = self.subviews[self.selectedIndex]
       
        image = selectView.subviews[0].subviews[0] as! ImageView
        image.image = selectItem.selectedImage
        if respondToDelegate {
            self.delegate?.didChange(selected: selectItem, index: selectedIndex)
        }
        
    }
    
    
    
    public override func mouseDown(with event: NSEvent) {
        let point:NSPoint = self.convert(event.locationInWindow, from: nil)
        
        var idx:Int = 0
        
        for subview in subviews {
            if subview.hitTest(point) != nil {
                setSelectedIndex(idx, respondToDelegate:true)
                return
            }
            idx += 1
        }
    }
    
    
}
