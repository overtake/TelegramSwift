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
    func scrollup()
}

public class TabBarView: View {

    private var tabs:[TabItem] = []
    public private(set) var selectedIndex:Int = 0
    
    public weak var delegate:TabViewDelegate?
    

    required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        autoresizesSubviews = false
        autoresizingMask = []
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
        let width = NSWidth(self.bounds)
        let height = NSHeight(self.bounds) - .borderSize
        let defWidth = width / CGFloat(self.tabs.count)
        self.removeAllSubviews()
        var xOffset:CGFloat = 0
        
        
        for tab in tabs {
            let itemWidth = defWidth
            let view = View(frame: NSMakeRect(xOffset, .borderSize, itemWidth, height))
            let container = View(frame: view.bounds)
            view.autoresizingMask = [.viewMinXMargin, .viewMaxXMargin, .viewWidthSizable]
            view.autoresizesSubviews = true
            let imageView = ImageView(frame: NSMakeRect(0, 0, tab.image.backingSize.width, tab.image.backingSize.height))
            imageView.image = tab.image
            container.addSubview(imageView)
            container.setFrameSize(NSMakeSize(NSWidth(imageView.frame), NSHeight(container.frame)))
            view.addSubview(container)
            
            if let subView = tab.subNode?.view {
                view.addSubview(subView)
            }
            
            imageView.center()
            container.center()

            self.addSubview(view)
            xOffset += itemWidth
        }
        
        self.setSelectedIndex(self.selectedIndex, respondToDelegate: false)
        setFrameSize(frame.size)
    }
    
    
    
    override public func setFrameSize(_ newSize: NSSize) {
        let previous:CGFloat = frame.width
        super.setFrameSize(newSize)
       // if previous != newSize.width {
            let width = NSWidth(self.bounds)
            let height = NSHeight(self.bounds) - .borderSize
            let defWidth = width / CGFloat( max(1, self.tabs.count) )
            var xOffset:CGFloat = 0
            
            var idx:Int = 0
            
            for subview in subviews {
                let w = idx == subviews.count - 1 ? defWidth - .borderSize : defWidth
                let child = subview.subviews[0]
                subview.frame = NSMakeRect(xOffset, .borderSize, w, height)
                child.center()
                xOffset += w
                
                idx += 1
            }
     //   }
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
        let selectItem = self.tabs[self.selectedIndex]
        let selectView = self.subviews[self.selectedIndex]
       
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
                if selectedIndex == idx {
                    self.delegate?.scrollup()
                } else {
                    setSelectedIndex(idx, respondToDelegate:true)
                }
                return
            }
            idx += 1
        }
    }
    
    
}
