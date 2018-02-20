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

open class ScrollView: NSScrollView{
    private var currentpos:ScrollPosition = ScrollPosition()
    public var deltaCorner:Int64 = 60
    
  
    override open static var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }

    public func scrollPosition(_ visibleRange: NSRange = NSMakeRange(NSNotFound, 0))  -> (current: ScrollPosition, previous: ScrollPosition) {
        
        let rect = NSMakeRect(contentView.bounds.minX, contentView.bounds.maxY,contentView.documentRect.width, contentView.documentRect.height)
        
        var d:ScrollDirection = .none
        
        
        if abs(currentpos.rect.minY - rect.minY) < 5 {
            return (currentpos, currentpos)
        }
        
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
    
    func updateScroll(_ visibleRange: NSRange = NSMakeRange(NSNotFound, 0)) -> Void {
        self.currentpos = ScrollPosition(NSMakeRect(contentView.bounds.minX, contentView.bounds.maxY,contentView.documentRect.width, contentView.documentRect.height), .none, visibleRange)
    }
    
    public var documentOffset:NSPoint {
        return NSMakePoint(NSMinX(self.contentView.bounds), NSMinY(self.contentView.bounds))
    }
    
    public var documentSize:NSSize {
        return self.contentView.documentRect.size;
    }
    

    open override func draw(_ dirtyRect: NSRect) {
       
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
        
        drawsBackground = false
        layerContentsRedrawPolicy = .never
        
        self.hasHorizontalScroller = false 
        self.horizontalScrollElasticity = .none
        self.verticalScroller?.scrollerStyle = .overlay
        autoresizingMask = []
        self.wantsLayer = true;
        layer?.backgroundColor = presentation.colors.background.cgColor

      //  verticalScrollElasticity = .automatic
        //allowsMagnification = true
        //self.hasVerticalScroller = false
        
       // self.scrollerStyle = .overlay
 
    }
    
    open override func setNeedsDisplay(_ invalidRect: NSRect) {
        
    }
    
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
    
    
//    override open func scrollWheel(with event: NSEvent) {
//        NSLog("\(event)")
//        var scrollPoint = self.contentView.bounds.origin
//       // var isInverted = CBool(UserDefaults.standard.object(forKey: "com.apple.swipescrolldirection")!)
////        if !isInverted {
////            scrollPoint.x += (event.scrollingDeltaY() + event.scrollingDeltaX())
////        }
////        else {
//            scrollPoint.y -= (event.scrollingDeltaY + event.scrollingDeltaY)
//       // }
//        self.clipView.scroll(to: scrollPoint)
//    }
    
    let dynamic:CGFloat = 100.0

    open override func scrollWheel(with event: NSEvent) {
        
        if deltaCorner > 0 {
            var origin = clipView.bounds.origin
            
            deltaCorner = max(Int64(floorToScreenPixels(scaleFactor: backingScaleFactor, frame.height / 6.0)),40)
            
            
            
            let deltaScrollY = min(max(Int64(event.scrollingDeltaY),-deltaCorner),deltaCorner)
            
            
            // NSLog("\(event.deltaY)")
            
            if  let cgEvent = event.cgEvent?.copy() {
                
                
                
                // cgEvent.setDoubleValueField(.scrollWheelEventDeltaAxis1, value: Double(min(max(-4,event.deltaY),4)))
                
                
                //if delta == deltaCorner || delta == -deltaCorner || delta == 0 {
                cgEvent.setIntegerValueField(.scrollWheelEventScrollCount, value: min(1,cgEvent.getIntegerValueField(.scrollWheelEventScrollCount)))
                // }
                cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: deltaScrollY)
                //            if event.scrollingDeltaY > 0 {
                //
                //            } else {
                //                cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: )
                //            }
                
                //   NSLog("\(cgEvent.getIntegerValueField(.scrollWheelEventScrollCount)) == \(delta)")
                
                //  cgEvent.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: 10)
                // cgEvent.setIntegerValueField(.scrollWheelEventScrollCount, value: Int64(delta))
                
                let newEvent = NSEvent(cgEvent: cgEvent)!
                
                super.scrollWheel(with: newEvent)
                
                
            }  else {
                //NSLog("\(cgEvent.getIntegerValueField(.scrollWheelEventScrollCount))")
                
                super.scrollWheel(with: event)
            }
            
            
            if origin == clipView.bounds.origin, abs(deltaScrollY) >= deltaCorner
            {
                
                if let documentView = documentView, !(self is HorizontalTableView) {
                    
                    if frame.minY < origin.y - frame.height - 50 {
                        if origin.y > documentView.frame.maxY + dynamic {
                            clipView.scroll(to: NSMakePoint(origin.x, documentView.frame.minY))
                        }
                        
                        if origin.y < documentView.frame.height {
                            if documentView.isFlipped {
                                if origin.y < documentView.frame.height - (frame.height + frame.minY) {
                                    origin.y -= CGFloat(deltaScrollY)
                                    clipView.scroll(to: origin)
                                    reflectScrolledClipView(clipView)
                                }
                            } else {
                                if origin.y + frame.height < documentView.frame.height {
                                    origin.y += CGFloat(deltaScrollY)
                                    clipView.scroll(to: origin)
                                    reflectScrolledClipView(clipView)
                                }
                                
                            }
                        }
                    } else if origin.y < -dynamic {
                        clipView.scroll(to: NSMakePoint(origin.x, 0))
                    }
                }
            }
        } else {
            super.scrollWheel(with: event)
        }
    }

    
    public func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    
    public func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    public func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
    }
    
}
