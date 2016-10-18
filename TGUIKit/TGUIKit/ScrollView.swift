//
//  ScrollView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

public enum ScrollDirection {
    case top;
    case bottom;
    case none;
}

public struct ScrollPosition : Equatable {
    public private(set) var rect:NSRect

    public private(set) var direction:ScrollDirection
    public init(_ rect:NSRect = NSZeroRect, _ direction:ScrollDirection = .none) {
        self.rect = rect
        self.direction = direction
    }
}

public func ==(lhs:ScrollPosition, rhs:ScrollPosition) -> Bool {
    return NSEqualRects(lhs.rect, rhs.rect) && lhs.direction == rhs.direction
}

open class ScrollView: NSScrollView, CALayerDelegate{
    private var currentpos:ScrollPosition = ScrollPosition()

    public var scrollPosition:ScrollPosition {
        
        let rect = NSMakeRect(NSMinX(self.contentView.bounds), NSMaxY(self.contentView.bounds),NSWidth(self.contentView.documentRect),NSHeight(self.contentView.documentRect))
        
        var d:ScrollDirection = .none
        
       // if(rect.origin.y < rect.size.height && rect.origin.y > 0) {
            if(NSMinY(currentpos.rect) > NSMinY(rect)) {
                d = .top
            } else if(NSMinY(currentpos.rect) < NSMinY(rect)) {
                d = .bottom
            }
      //  }
        
        
        let n = ScrollPosition(rect,d)
        currentpos = n
        return n
    }
    
    func updateScroll() -> Void {
        self.currentpos = self.scrollPosition
    }
    
    public var documentOffset:NSPoint {
        return NSMakePoint(NSMinX(self.contentView.bounds), NSMinY(self.contentView.bounds))
    }
    
    public var documentSize:NSSize {
        return self.contentView.documentRect.size;
    }
    

    open override func draw(_ dirtyRect: NSRect) {
       
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(bounds)
    }
    
    public var clipView:TGClipView {
        return self.contentView as! TGClipView
    }
    

     override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.wantsLayer = true;
        self.layer?.delegate = self
        self.canDrawSubviewsIntoLayer = true
        self.layer?.drawsAsynchronously = System.drawAsync
        self.layer?.isOpaque = true
        
    //    self.contentView.wantsLayer = true
     //   self.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
     //   self.contentView.layer?.drawsAsynchronously = System.drawAsync
        
     //   self.layerContentsRedrawPolicy = .onSetNeedsDisplay;
       // self.layer?.isOpaque = false
        
        let clipView = TGClipView(frame:self.contentView.frame)
        self.contentView = clipView;
        
        self.scrollerStyle = .overlay
 
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    

    

    
}
