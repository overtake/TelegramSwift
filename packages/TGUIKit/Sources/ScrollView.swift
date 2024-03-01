//
//  ScrollView.swift
//  TGUIKit
//
//  Created by keepcoder on 07/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import Foundation
public enum ScrollDirection {
    case top;
    case bottom;
    case none;
}

public func calculateScrollSpeed(scrollPositions: [CGFloat]) -> CGFloat? {
    guard scrollPositions.count >= 2 else {
        return nil // Not enough data to calculate speed
    }
    
    let firstPosition = scrollPositions.max()!
    let lastPosition = scrollPositions.min()!
    
    let distance = lastPosition - firstPosition
    let timeElapsed = CGFloat(scrollPositions.count - 1)
    
    let speed = distance / timeElapsed
    return speed
}

public struct ScrollPosition : Equatable {
    public private(set) var rect:NSRect
    public private(set) var visibleRows: NSRange
    public private(set) var direction:ScrollDirection
    public init(_ rect:NSRect = NSZeroRect, _ direction:ScrollDirection = .none, _ visibleRows: NSRange = NSMakeRange(NSNotFound, 0)) {
        self.rect = rect
        self.visibleRows = visibleRows
        self.direction = direction
    }
}

public func ==(lhs:ScrollPosition, rhs:ScrollPosition) -> Bool {
    return NSEqualRects(lhs.rect, rhs.rect) && lhs.direction == rhs.direction && NSEqualRanges(lhs.visibleRows, rhs.visibleRows)
}

final class Scroller : NSScroller {
    weak var scrollView: NSScrollView?
    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()
        if let scrollView = self.scrollView {
            if scrollView.contentView.documentRect.height > scrollView.frame.height {
                self.drawKnob()
            }
        }
    }
}

extension NSScroller {
    
}

final class OverlayScroller : NSScroller {
    weak var scrollView: NSScrollView?

    init() {
        super.init(frame: .zero)
    }
    
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override var scrollerStyle: NSScroller.Style {
        get {
            return .overlay
        }
        set {
            super.scrollerStyle = .overlay
        }
    }
    private var drawKnowIfNeeded = false
    
    override func draw(_ dirtyRect: NSRect) {
        drawKnowIfNeeded = true
        super.draw(dirtyRect)
//        if let tableView = self.scrollView as? TableView {
//            if tableView.liveScrolling || tableView.clipView.isAnimateScrolling, drawKnowIfNeeded {
//                drawKnob()
//            }
//        }
    }
    override func drawKnob() {
        super.drawKnob()
        drawKnowIfNeeded = false
    }
}

open class ScrollView: NSScrollView{
    private var currentpos:ScrollPosition = ScrollPosition()
    public var deltaCorner:Int64 = 60
    
    public var applyExternalScroll:((NSEvent)->Bool)? = nil
  
    override public static var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }
    
//    open override var translatesAutoresizingMaskIntoConstraints: Bool {
//        get {
//            return false
//        }
//        set {
//
//        }
//    }

    public func scrollPosition(_ visibleRange: NSRange = NSMakeRange(NSNotFound, 0))  -> (current: ScrollPosition, previous: ScrollPosition) {
        
        let rect = NSMakeRect(contentView.bounds.minX, contentView.bounds.maxY,contentView.documentRect.width, contentView.documentRect.height)
        
        var d:ScrollDirection = currentpos.direction
                
        if(currentpos.rect.minY > rect.minY) {
            d = .top
        } else if(currentpos.rect.minY < rect.minY) {
            d = .bottom
        }
        
        let n = ScrollPosition(rect, d, visibleRange)
        let previous = currentpos
        currentpos = n
        return (n, previous)
    }
    
    public var currentScroll: ScrollPosition {
        return currentpos
    }
    
    open override func isAccessibilityElement() -> Bool {
        return false
    }
    
    func resetScroll(_ visibleRange: NSRange = NSMakeRange(NSNotFound, 0)) -> Void {
        self.currentpos = ScrollPosition(NSMakeRect(contentView.bounds.minX, contentView.bounds.maxY,contentView.documentRect.width, contentView.documentRect.height), .none, visibleRange)
    }
    
    public var documentOffset:NSPoint {
        return clipView.documentOffset
    }
    
    open override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        return super.knowsPageRange(range)
    }
    
    public var documentSize:NSSize {
        return self.contentView.documentRect.size;
    }
//    
//
//    open override func draw(_ dirtyRect: NSRect) {
//       
//    }
    
    
    public var _mouseDownCanMoveWindow: Bool = false
    public override var mouseDownCanMoveWindow: Bool {
        return _mouseDownCanMoveWindow
    }
    
    public var clipView:TGClipView {
        return self.contentView as! TGClipView
    }
    

     override public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
      

       // self.layer?.delegate = self
//        self.canDrawSubviewsIntoLayer = true
//        self.layer?.drawsAsynchronously = System.drawAsync
        
    //    self.contentView.wantsLayer = true
     //   self.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
     //   self.contentView.layer?.drawsAsynchronously = System.drawAsync
        
       // self.layerContentsRedrawPolicy = .never;
        //self.layer?.isOpaque = true
        
        let clipView = TGClipView(frame:self.contentView.frame)
        self.contentView = clipView;
         
         self.automaticallyAdjustsContentInsets = false
        
        drawsBackground = false
        layerContentsRedrawPolicy = .never
        
       // self.hasHorizontalScroller = false
       // self.horizontalScrollElasticity = .automatic
      //  self.verticalScroller?.scrollerStyle = .overlay
        autoresizingMask = []
        self.wantsLayer = true;
        layer?.backgroundColor = presentation.colors.background.cgColor
      //  verticalScrollElasticity = .automatic
        //allowsMagnification = true
        //self.hasVerticalScroller = false
        
        self.scrollerStyle = .overlay
         
         if NSScroller.preferredScrollerStyle == .legacy {
             let scroller = Scroller()
             scroller.scrollView = self
             self.verticalScroller = scroller
         } 
 
    }
    
    
    
    open override func draw(_ dirtyRect: NSRect) {

    }
//
    
    open override func scrollWheel(with event: NSEvent) {
        
        guard let window = window as? Window else {
            super.scrollWheel(with: event)
            return
        }
        
        if let applyExternalScroll = self.applyExternalScroll {
            if applyExternalScroll(event) {
                return
            }
        }
        
        if !window.inLiveSwiping {
            super.scrollWheel(with: event)
        }
//
    }
    
//    open override func setNeedsDisplay(_ invalidRect: NSRect) {
//
//    }
//    
    open override var scrollerStyle: NSScroller.Style {
        set {
            super.scrollerStyle = .overlay
        }
        get {
            return .overlay
        }
    }
    
  
//    
//    open override var hasVerticalScroller: Bool {
//        get {
//            return true
//        }
//        set {
//            super.hasVerticalScroller = newValue
//        }
//    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        assertOnMainThread()
    }
    
    public func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    public func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    public func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: CAMediaTimingFunctionName = CAMediaTimingFunctionName.easeOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
    }
    
}
