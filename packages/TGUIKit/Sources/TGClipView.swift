//
//  TGClipView.swift
//  TGUIKit
//
//  Created by keepcoder on 12/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import CoreVideo
import SwiftSignalKit
public class TGClipView: NSClipView,CALayerDelegate {
    
    var border:BorderType? {
        didSet {
            self.layerContentsRedrawPolicy = .onSetNeedsDisplay
            super.needsDisplay = true
             self.layerContentsRedrawPolicy = .never
        }
    }
    
    var displayLink:CVDisplayLink?
    var shouldAnimateOriginChange:Bool = false
    var destinationOrigin:NSPoint?
    
    var backgroundMode: TableBackgroundMode = .plain {
        didSet {
            needsDisplay = true
        }
    }
    
    public override var needsDisplay: Bool {
        set {
            //self.layerContentsRedrawPolicy = .onSetNeedsDisplay
            super.needsDisplay = needsDisplay
           // self.layerContentsRedrawPolicy = .never
        }
        get {
            return super.needsDisplay
        }
    }
    public var _mouseDownCanMoveWindow: Bool = false
    public override var mouseDownCanMoveWindow: Bool {
        return _mouseDownCanMoveWindow
    }
    
    weak var containingScrollView:NSScrollView? {
        
        if let scroll = self.enclosingScrollView {
            return scroll 
        } else {
            if let scroll = self.superview as? NSScrollView {
                return scroll
            }
            
            return nil
        }
        
    }
    var scrollCompletion:((_ success:Bool) ->Void)?
    public var decelerationRate:CGFloat = 0.8
    
    
    public var isScrolling: Bool {
        if let displayLink = displayLink {
            return CVDisplayLinkIsRunning(displayLink)
        }
        return false
    }
    public var destination: NSPoint? {
        return self.destinationOrigin
    }

    override init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
        //self.wantsLayer = true
        backgroundColor = .clear
        self.layerContentsRedrawPolicy = .never
      //  self.layer?.drawsAsynchronously = System.drawAsync
        //self.layer?.delegate = self
//        createDisplayLink()

    }
    
    override public static var isCompatibleWithResponsiveScrolling: Bool {
        return true
    }
    
    public override var backgroundColor: NSColor {
        set {
            super.backgroundColor = .clear
        }
        get {
            return .clear
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func draw(_ dirtyRect: NSRect) {
        
    }
    
//    override public func setNeedsDisplay(_ invalidRect: NSRect) {
//        
//    }
    
    public func draw(_ layer: CALayer, in ctx: CGContext) {
       // ctx.clear(bounds)

        
           // ctx.setFillColor(NSColor.clear.cgColor)
           // ctx.fill(bounds)
        

        if let border = border {
            
            ctx.setFillColor(presentation.colors.border.cgColor)
            
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
        if displayLink != nil {
            return
        }
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
    
    deinit {
        endScroll()
        NotificationCenter.default.removeObserver(self)
    }
    
    
    func beginScroll() -> Void {
        createDisplayLink()
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
        if layer?.animation(forKey: "bounds") != nil {
            return true
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
        self.displayLink = nil
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
            let lastOrigin:CGPoint = o;
            var _:CGFloat = self.decelerationRate;
            
            
            
            o.x = ceil(o.x + (destination.x - o.x) * (1 - self.decelerationRate));
            o.y = ceil(o.y + (destination.y - o.y) * (1 - self.decelerationRate));
            
            
            super.scroll(to: o)
            
            
            // Make this call so that we can force an update of the scroller positions.
            self.containingScrollView?.reflectScrolledClipView(self);
            
            if ((abs(o.x - lastOrigin.x) < 0.1 && abs(o.y - lastOrigin.y) < 0.1)) {
                if destination.x == o.x && destination.y == o.y {
                    self.endScroll()
                    super.scroll(to: o)
                    handleCompletionIfNeeded(withSuccess: true)
                } else {
                    _ = destination.x - o.x
                    let ydif = ceil(destination.y - o.y)
                    let xdif = ceil(destination.x - o.x)

         
                    if ydif != 0 {
                        let incY = abs(ydif) - abs(ydif + 1)
                        o.y -= incY
                    }
                    if xdif != 0 {
                        let incX = abs(xdif) - abs(xdif + 1)
                        o.x -= incX
                    }
                    super.scroll(to: o)
                }
                
                
            }
        }
        

    }
    
    override public func viewWillMove(toWindow newWindow: NSWindow?) {
//        if let w = newWindow {
//
//            NotificationCenter.default.addObserver(self, selector: #selector(updateCVDisplay), name: NSWindow.didChangeScreenNotification, object: w)
//
//        } else {
//            NotificationCenter.default.removeObserver(self, name: NSWindow.didChangeScreenNotification, object: self.window)
//        }
        
        super.viewWillMove(toWindow: newWindow)
    }
    
//    @objc func updateCVDisplay(_ notification:NSNotification? = nil) -> Void {
//        if let displayLink = displayLink, let _ = NSScreen.main {
//            CVDisplayLinkSetCurrentCGDisplay(displayLink, CGMainDisplayID());
//        }
//    }
    
    
    func scrollRectToVisible(_ rect: NSRect, animated: Bool) -> Bool {
        self.shouldAnimateOriginChange = animated
        return super.scrollToVisible(rect)
    }
    
    func scrollRectToVisible(_ rect: CGRect, animated: Bool, completion: @escaping (Bool) -> Void) -> Bool {
        self.scrollCompletion = completion
        let success = self.scrollRectToVisible(rect, animated: animated)
        if !animated || !success {
            self.handleCompletionIfNeeded(withSuccess: success)
        }
        return success
    }
    
    
    public func scroll(to point: NSPoint, animated:Bool, completion: @escaping (Bool) -> Void = {_ in})  {
        
        self.scrollCompletion?(false)
        self.shouldAnimateOriginChange = animated
        self.scrollCompletion = completion
        if animated {
            self.layer?.removeAllAnimations()
            beginScroll()
        }
        if animated && abs(bounds.minY - point.y) > frame.height {
            let y:CGFloat
            if bounds.minY < point.y {
                y = point.y - floor(frame.height / 2)
            } else {
                y = point.y + floor(frame.height / 2)
            }
            super.scroll(to: NSMakePoint(point.x,y))
            DispatchQueue.main.async(execute: { [weak self] in
                self?.scroll(to: point)
            })
        } else {
            self.scroll(to: point)
        }
        
    }
    
    public func justScroll(to newOrigin:NSPoint) {
        super.scroll(to: newOrigin)
    }
    
    
    override public func scroll(to newOrigin:NSPoint) -> Void {
        let newOrigin = NSMakePoint(round(newOrigin.x), round(newOrigin.y))
        if (self.shouldAnimateOriginChange) {
            self.shouldAnimateOriginChange = false;
            self.destinationOrigin = newOrigin;
            self.beginScroll()
        } else {
            if !isAnimateScrolling {
                self.destinationOrigin = newOrigin;
                self.endScroll()
                super.scroll(to: newOrigin)
                Queue.mainQueue().justDispatch {
                    self.handleCompletionIfNeeded(withSuccess: true)
                }
            }
        }
        
    }
    
    public override var bounds: NSRect {
        set {
            super.bounds = newValue
        }
        get {
            return super.bounds
        }
    }
    
    
    func handleCompletionIfNeeded(withSuccess success: Bool) {
        if self.scrollCompletion != nil {
          //  super.scroll(to: bounds.origin)
            self.scrollCompletion!(success)
            self.scrollCompletion = nil
        }
    }
    
}
