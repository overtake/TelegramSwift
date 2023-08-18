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

private final class ClipLayer : SimpleLayer {
    override var bounds: CGRect {
        didSet {
            NSLog("\(bounds)")
        }
    }
}

public class TGClipView: NSClipView,CALayerDelegate {
    
    var border:BorderType? {
        didSet {
//            self.layerContentsRedrawPolicy = .onSetNeedsDisplay
//            super.needsDisplay = true
//            self.layerContentsRedrawPolicy = .never
        }
    }
    
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
            super.needsDisplay = newValue
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
    
    
    public var destination: NSPoint? {
        return self.destinationOrigin
    }

    override init(frame frameRect: NSRect) {
        
        super.init(frame: frameRect)
//        self.backgroundColor = .clear
        self.wantsLayer = true
       // self.layerContentsRedrawPolicy = .never
      //  self.layer?.drawsAsynchronously = System.drawAsync
        //self.layer?.delegate = self
//        createDisplayLink()

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
//
//    public override func draw(_ dirtyRect: NSRect) {
//
//    }
//
////    override public func setNeedsDisplay(_ invalidRect: NSRect) {
////
////    }
//
//    public func draw(_ layer: CALayer, in ctx: CGContext) {
//       // ctx.clear(bounds)
//
//
//           // ctx.setFillColor(NSColor.clear.cgColor)
//           // ctx.fill(bounds)
//
//
//        if let border = border {
//
//            ctx.setFillColor(presentation.colors.border.cgColor)
//
//            if border.contains(.Top) {
//                ctx.fill(NSMakeRect(0, NSHeight(self.frame) - .borderSize, NSWidth(self.frame), .borderSize))
//            }
//            if border.contains(.Bottom) {
//                ctx.fill(NSMakeRect(0, 0, NSWidth(self.frame), .borderSize))
//            }
//            if border.contains(.Left) {
//                ctx.fill(NSMakeRect(0, 0, .borderSize, NSHeight(self.frame)))
//            }
//            if border.contains(.Right) {
//                ctx.fill(NSMakeRect(NSWidth(self.frame) - .borderSize, 0, .borderSize, NSHeight(self.frame)))
//            }
//
//        }
//    }
//

    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public var isAnimateScrolling:Bool {
        return self.point != nil
    }
    
    override public func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
    }
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
    
    var documentOffset: NSPoint {
        return self.point ?? self.bounds.origin
    }
    
    public func updateBounds(to point: NSPoint) {
        if self.bounds.origin != point {
            super.scroll(to: point)
        }
    }
        
    private(set) var point: NSPoint?
    
    public func scroll(to point: NSPoint, animated:Bool, completion: @escaping (Bool) -> Void = {_ in})  {
        
        if point == self.destinationOrigin {
            return
        }
        self.scrollCompletion = completion
        self.destinationOrigin = point
        if animated {
            
            self.point = point
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.35
                let timingFunction = CAMediaTimingFunction(controlPoints: 0.5, 1.0 + 0.4 / 3.0, 1.0, 1.0)
                ctx.timingFunction = timingFunction
                self.animator().setBoundsOrigin(point)
            }, completionHandler: {
//                if point != self.bounds.origin, self.point == point {
//                    self.setBoundsOrigin(point)
//                }
                self.destinationOrigin = nil
                self.point = nil
                self.scrollCompletion?(point == self.bounds.origin)
            })
        } else {
            self.updateBounds(to: point)
            self.point = nil
            self.destinationOrigin = nil
            self.scrollCompletion?(false)
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
    
//    public override func scroll(to newOrigin: NSPoint) {
//        bounds.origin = newOrigin
//    }
    
    func handleCompletionIfNeeded(withSuccess success: Bool) {
        self.destinationOrigin = nil
        if self.scrollCompletion != nil {
          //  super.scroll(to: bounds.origin)
            self.scrollCompletion!(success)
            self.scrollCompletion = nil
        }
    }
    
    
    public override func isAccessibilityElement() -> Bool {
        return false
    }
    public override func accessibilityParent() -> Any? {
        return nil
    }
}
