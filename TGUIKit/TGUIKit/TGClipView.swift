//
//  TGClipView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import CoreVideo
import SwiftSignalKitMac
import TGUIKit
public class TGClipView: NSClipView,CALayerDelegate {
    
    var border:BorderType?
    
    var displayLink:CVDisplayLink?
    var shouldAnimateOriginChange:Bool = false
    var destinationOrigin:NSPoint?
    weak var containingScrollView:NSScrollView? {
        
        if let scroll = self.enclosingScrollView {
            return scroll as! NSScrollView
        } else {
            if let scroll = (self.superview as? NSScrollView) {
                return self.superview as! NSScrollView
            }
            
            return nil
        }
        
    }
    var scrollCompletion:((_ success:Bool) ->Void)?
    public var decelerationRate:CGFloat = 0.78
    

    override init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        self.wantsLayer = true
        //self.canDrawSubviewsIntoLayer = true
      //  self.layer?.drawsAsynchronously = System.drawAsync
        self.layer?.delegate = self
        createDisplayLink()

    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        
    }
    
    public func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(self.bounds)

        if let border = border {
            
            ctx.setFillColor(NSColor.border.cgColor)
            
            if border.contains(.Top) {
                ctx.fill(NSMakeRect(0, NSHeight(self.frame) - .borderSize, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Bottom) {
                ctx.fill(NSMakeRect(0, 0, NSWidth(self.frame), .borderSize))
            }
            if border.contains(.Left) {
                ctx.fill(NSMakeRect(0, 0, .borderSize, NSHeight(self.frame)))
            }
            if border.contains(.Right) {
                ctx.fill(NSMakeRect(NSWidth(self.frame) - .borderSize, 0, .borderSize, NSHeight(self.frame)))
            }
            
        }
    }
    
    private func createDisplayLink() {
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let displayLink = displayLink else {
            return
        }
        
        let callback: CVDisplayLinkOutputCallback = { (_, _, _, _, _, userInfo) -> CVReturn in
            let clipView = Unmanaged<TGClipView>.fromOpaque(userInfo!).takeUnretainedValue()
            
            Queue.mainQueue().async {
                clipView.updateOrigin()
            }
            
            return kCVReturnSuccess
        }
        
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, userInfo)
    }
    
    
    func beginScroll() -> Void {
        if let displayLink = displayLink {
            if (CVDisplayLinkIsRunning(displayLink)) {
                return
            }
            
            CVDisplayLinkStart(displayLink)
        }
        
    }
    
    public var isAnimateScrolling:Bool {
        if let displayLink = displayLink {
            if (CVDisplayLinkIsRunning(displayLink)) {
                return true
            }
        }
        return false
    }
    
    func endScroll() -> Void {
        if let displayLink = displayLink {
            if (!CVDisplayLinkIsRunning(displayLink)) {
                return;
            }
            CVDisplayLinkStop(displayLink);
        }
        
    }
//    
//    func easeInOutQuad (percentComplete: CGFloat, elapsedTimeMs: CGFloat, startValue: CGFloat, endValue: CGFloat, totalDuration: CGFloat) -> CGFloat {
//        var newElapsedTimeMs = elapsedTimeMs
//        newElapsedTimeMs /= totalDuration/2
//        
//        if newElapsedTimeMs < 1 {
//            return endValue/2*newElapsedTimeMs*newElapsedTimeMs + startValue
//        }
//        newElapsedTimeMs = newElapsedTimeMs - 1
//        return -endValue/2 * ((newElapsedTimeMs)*(newElapsedTimeMs-2) - 1) + startValue
//    }

    
    public func updateOrigin() -> Void {
        if (self.window == nil) {
            self.endScroll()
            return;
        }
        
        if let destination = self.destinationOrigin {
            var o:CGPoint = self.bounds.origin;
            var lastOrigin:CGPoint = o;
            var deceleration:CGFloat = self.decelerationRate;
            
            
            
            o.x = ceil(o.x + (destination.x - o.x) * (1 - self.decelerationRate));
            o.y = ceil(o.y + (destination.y - o.y) * (1 - self.decelerationRate));
            
            
            super.scroll(to: o)
            
            
            // Make this call so that we can force an update of the scroller positions.
            self.containingScrollView?.reflectScrolledClipView(self);
            
            if ((fabs(o.x - lastOrigin.x) < 0.1 && fabs(o.y - lastOrigin.y) < 0.1)) {
                if destination.x == o.x && destination.y == o.y {
                    self.endScroll()
                   
                    handleCompletionIfNeeded(withSuccess: true)
                } else {
                    let xdif = destination.x - o.x
                    let ydif = destination.y - o.y
                    
                    if xdif != 0 {
                        let incX = abs(xdif) - abs(xdif + 1)
                        o.x -= incX
                    }
                    
                    if ydif != 0 {
                        let incY = abs(ydif) - abs(ydif + 1)
                        o.y -= incY
                    }

                }
                
                super.scroll(to: o)
                
            }
        }
        

    }
    
    
    
    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        if let w = newWindow {
            
            NotificationCenter.default.addObserver(self, selector: #selector(updateCVDisplay), name: NSNotification.Name.NSWindowDidChangeScreen, object: w)
            
        } else {
            NotificationCenter.default.removeObserver(self, name: NSNotification.Name.NSWindowDidChangeScreen, object: self.window)
        }
        
        super.viewWillMove(toWindow: newWindow)
    }
    
    func updateCVDisplay(_ notification:NSNotification? = nil) -> Void {
        
        if let s = self.window?.screen {
            CVDisplayLinkSetCurrentCGDisplay(self.displayLink!, CGMainDisplayID());
        } else {
            let dictionary:[String:Any] = (NSScreen.main()?.deviceDescription)!
            let screenId = dictionary["NSScreenNumber"] as! NSNumber
            let displayID:CGDirectDisplayID = screenId.uint32Value
            CVDisplayLinkSetCurrentCGDisplay(self.displayLink!, displayID);
        }
        
    }
    
    
    func scrollRectToVisible(_ rect: NSRect, animated: Bool) -> Bool {
        self.shouldAnimateOriginChange = animated
        return super.scrollToVisible(rect)
    }
    
    func scrollRectToVisible(_ rect: CGRect, animated: Bool, completion: @escaping (Bool) -> Void) -> Bool {
        self.scrollCompletion = completion
        var success = self.scrollRectToVisible(rect, animated: animated)
        if !animated || !success {
            self.handleCompletionIfNeeded(withSuccess: success)
        }
        return success
    }
    
    let maxScrollHeight:CGFloat = 1500.0
    
    public func scroll(to point: NSPoint, animated:Bool)  {
        self.shouldAnimateOriginChange = animated
        
        if animated && abs(bounds.minY - point.y) > maxScrollHeight {
            let y:CGFloat
            if bounds.minY < point.y {
                y = point.y - maxScrollHeight
            } else {
                y = point.y + maxScrollHeight
            }
            super.scroll(to: NSMakePoint(point.x,y))
        }
        
        self.scroll(to: point)
    }
    
    
    override public func scroll(to newOrigin:NSPoint) -> Void {
        
        if (self.shouldAnimateOriginChange) {
            self.shouldAnimateOriginChange = false;
            self.destinationOrigin = newOrigin;
            self.beginScroll()
        } else {
            self.endScroll()
            super.scroll(to: newOrigin)
        }
        
    }
    
    
    func handleCompletionIfNeeded(withSuccess success: Bool) {
        if self.scrollCompletion != nil {
            self.scrollCompletion!(success)
            self.scrollCompletion = nil
        }
    }
    
}
