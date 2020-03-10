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
        
        ctx.setFillColor(presentation.colors.border.cgColor)
        ctx.fill(NSMakeRect(frame.width - .borderSize, 0, .borderSize, frame.height))
        ctx.fill(NSMakeRect(0, 0, frame.width, .borderSize))

    }
    
    func control(for index: Int) -> Control {
        return subviews[index] as! Control
    }
    
    func addTab(_ tab: TabItem) {
        self.tabs.append(tab)
        self.redraw()
    }
    func replaceTab(_ tab: TabItem, at index:Int) {
        self.tabs.remove(at: index)
        self.tabs.insert(tab, at: index)
        
        let subview = self.subviews[index].subviews.first?.subviews.first as? ImageView
        subview?.animates = true
        subview?.image = self.selectedIndex == index ? tab.selectedImage : tab.image
        subview?.animates = false
        (self.subviews[index] as? Control)?.backgroundColor = presentation.colors.background
        (self.subviews[index].subviews.first as? View)?.backgroundColor = presentation.colors.background

        if let subView = tab.subNode?.view {
            while self.subviews[index].subviews.count > 1 {
                self.subviews[index].subviews.last?.removeFromSuperview()
            }
            self.subviews[index].addSubview(subView)
            tab.subNode?.update()
        }
    }
    
    func insertTab(_ tab: TabItem, at index: Int) {
        self.tabs.insert(tab, at: index)
        if selectedIndex >= index {
            selectedIndex += 1
        }
        self.redraw()
    }
    
    func removeTab(_ tab: TabItem) {
        self.tabs.remove(at: self.tabs.firstIndex(of: tab)!)
        self.redraw()
    }
    
    func enumerateItems(_ f:(TabItem)->Bool) {
        for item in tabs {
            if f(item) {
                break
            }
        }
    }
    
    func removeTab(at index: Int) {
        self.tabs.remove(at: index)
        if selectedIndex >= index {
            selectedIndex -= 1
        }
        self.redraw()
    }
    public var isEmpty:Bool {
        return tabs.isEmpty
    }
    public var count:Int {
        return tabs.count
    }
    public func tab(at index:Int) -> TabItem {
        return self.tabs[index]
    }
    public func showTooltip(text: String, for index: Int) -> Void {
        tooltip(for: self.subviews[index], text: text)
    }
    
    func redraw() {
        let width = NSWidth(self.bounds)
        let height = NSHeight(self.bounds) - .borderSize
        let defWidth = width / CGFloat(self.tabs.count)
        self.removeAllSubviews()
        var xOffset:CGFloat = 0
        
        
        for i in 0 ..< tabs.count {
            let tab = tabs[i]
            let itemWidth = defWidth
            let view = Control(frame: NSMakeRect(xOffset, .borderSize, itemWidth, height))
            view.backgroundColor = presentation.colors.background
            let container = View(frame: view.bounds)
            view.set(handler: { [weak self] control in
                self?.tabs[i].longHoverHandler?(control)
            }, for: .RightDown)
            
            view.set(handler: { [weak self] control in
                if let strongSelf = self {
                    if strongSelf.selectedIndex == i {
                        strongSelf.delegate?.scrollup()
                    } else {
                        strongSelf.setSelectedIndex(i, respondToDelegate:true, animated: true)
                    }
                }
            }, for: .Down)
            view.autoresizingMask = [.minXMargin, .maxXMargin, .width]
            view.autoresizesSubviews = true
            let imageView = tab.makeView()
            tab.setSelected(false, for: imageView, animated: false)
            container.addSubview(imageView)
            container.backgroundColor = presentation.colors.background
            container.setFrameSize(NSMakeSize(NSWidth(imageView.frame), NSHeight(container.frame)))
            view.addSubview(container)
            
            if let subView = tab.subNode?.view {
                view.addSubview(subView)
                tab.subNode?.update()
            }
            
            imageView.center()
            container.center()

            self.addSubview(view)
            xOffset += itemWidth
        }
        
        self.setSelectedIndex(self.selectedIndex, respondToDelegate: false, animated: false)
        setFrameSize(frame.size)
    }
    
    public override func updateLocalizationAndTheme(theme: PresentationTheme) {
        for subview in subviews {
            subview.background = presentation.colors.background
            for container in subview.subviews {
                //container.background = presentation.colors.background
            }
        }
        self.backgroundColor = presentation.colors.background
        needsDisplay = true
        super.updateLocalizationAndTheme(theme: theme)
    }
    
    
    override public func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
       // if previous != newSize.width {
            let width = NSWidth(self.bounds)
            let height = NSHeight(self.bounds) - .borderSize
            let defWidth = floorToScreenPixels(backingScaleFactor, width / CGFloat( max(1, self.tabs.count) ))
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
    
    
    public func setSelectedIndex(_ selectedIndex: Int, respondToDelegate: Bool, animated: Bool) {
        if selectedIndex > self.tabs.count || self.tabs.count == 0 {
            return
        }
        let deselectItem = self.tabs[self.selectedIndex]
        let deselectView = self.subviews[self.selectedIndex]
        
        deselectItem.setSelected(false, for: deselectView.subviews[0].subviews[0], animated: animated)
        self.selectedIndex = selectedIndex
        let selectItem = self.tabs[self.selectedIndex]
        let selectView = self.subviews[self.selectedIndex]
       
        selectItem.setSelected(true, for: selectView.subviews[0].subviews[0], animated: animated)
        if respondToDelegate {
            self.delegate?.didChange(selected: selectItem, index: selectedIndex)
        }
        
    }
    
    
    
    
}
