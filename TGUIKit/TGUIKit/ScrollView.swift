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

private class Scroller : NSScroller {
    fileprivate override func sendAction(on mask: NSEventMask) -> Int {
        return super.sendAction(on: mask)
    }
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
    public var deltaCorner:Int64 = 60
    private var scroller:Scroller?

    public var scrollPosition:ScrollPosition {
        
//        if self.contentView.bounds.minY < 0 {
//            return ScrollPosition(currentpos.rect,.none)
//        }
        
        let rect = NSMakeRect(NSMinX(self.contentView.bounds), NSMaxY(self.contentView.bounds),NSWidth(self.contentView.documentRect),NSHeight(self.contentView.documentRect))
        
        var d:ScrollDirection = .none
        
        
        if abs(currentpos.rect.minY - rect.minY) < 5 {
            return currentpos
        }
        
       // if(rect.origin.y < rect.size.height && rect.origin.y > 0) {
            if(currentpos.rect.minY > rect.minY) {
                d = .top
            } else if(currentpos.rect.minY < rect.minY) {
                d = .bottom
            }
      //  }
        
        
        let n = ScrollPosition(rect,d)
        currentpos = n
        return n
    }
    
    func updateScroll() -> Void {
        self.currentpos = ScrollPosition(NSMakeRect(NSMinX(self.contentView.bounds), NSMaxY(self.contentView.bounds),NSWidth(self.contentView.documentRect),NSHeight(self.contentView.documentRect))
, .none)
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
        
        scroller = Scroller(frame: self.bounds)
        self.wantsLayer = true;

        self.layer?.delegate = self
//        self.canDrawSubviewsIntoLayer = true
//        self.layer?.drawsAsynchronously = System.drawAsync
        
    //    self.contentView.wantsLayer = true
     //   self.contentView.layerContentsRedrawPolicy = .onSetNeedsDisplay
     //   self.contentView.layer?.drawsAsynchronously = System.drawAsync
        
     //   self.layerContentsRedrawPolicy = .onSetNeedsDisplay;
       // self.layer?.isOpaque = false
        
        let clipView = TGClipView(frame:self.contentView.frame)
        self.contentView = clipView;
        
        
        
      //  verticalScrollElasticity = .automatic
        //allowsMagnification = true
        //self.hasVerticalScroller = false
        
       // self.scrollerStyle = .overlay
 
    }
    
  
    
    open override var hasVerticalScroller: Bool {
        get {
            return true
        }
        set {
            super.hasVerticalScroller = newValue
        }
    }
    
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
        var origin = clipView.bounds.origin
        let frameOrigin = clipView.frame.origin
        
        deltaCorner = max(Int64(floorToScreenPixels(frame.height / 6.0)),40)
        
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
        
        
        if origin == clipView.bounds.origin
        {
            
            if let documentView = documentView, !(self is HorizontalTableView) {
                
                if frame.minY < origin.y - frame.height - 50 && deltaScrollY != 0 {
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

    }
//
    
}
