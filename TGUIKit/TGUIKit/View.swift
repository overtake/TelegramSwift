//
//  View.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation
import SwiftSignalKitMac
public let kUIKitAnimationBackground = "UIKitAnimationBackground"

public protocol AppearanceViewProtocol {
     func updateLocalizationAndTheme()
}

class ViewLayer : CALayer {
    override init(layer: Any) {
        super.init(layer: layer)
    }
    
    override open class func needsDisplay(forKey:String) -> Bool {
        if forKey == kUIKitAnimationBackground {
            return true
        }
        return false
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

public struct BorderType: OptionSet {
    public var rawValue: UInt32
    
    public init(rawValue: UInt32) {
        self.rawValue = rawValue
    }
    
    public init() {
        self.rawValue = 0
    }
    
    public init(_ flags: BorderType) {
        var rawValue: UInt32 = 0
        
        if flags.contains(BorderType.Top) {
            rawValue |= BorderType.Top.rawValue
        }
        
        if flags.contains(BorderType.Bottom) {
            rawValue |= BorderType.Bottom.rawValue
        }
        
        if flags.contains(BorderType.Left) {
            rawValue |= BorderType.Left.rawValue
        }
        
        if flags.contains(BorderType.Right) {
            rawValue |= BorderType.Right.rawValue
        }
        
        self.rawValue = rawValue
    }
    
    public static let Top = BorderType(rawValue: 1)
    public static let Bottom = BorderType(rawValue: 2)
    public static let Left = BorderType(rawValue: 4)
    public static let Right = BorderType(rawValue: 8)
}

public protocol ViewDisplayDelegate : class {
    func draw(_ layer: CALayer, in ctx: CGContext);
}

public class CustomViewHandlers {
    public var size:((NSSize) ->Void)?
    public var origin:((NSPoint) ->Void)?
    public var layout:((View) ->Void)?
    
    deinit {
        var bp:Int = 0
        bp += 1
    }
}

public var viewEnableTouchBar: Bool = true



open class View : NSView, CALayerDelegate, AppearanceViewProtocol {
    
    public var userInteractionEnabled:Bool = true
    
    public var animates:Bool = false
    
    public var isEventLess: Bool = false
    
    public weak var displayDelegate:ViewDisplayDelegate?
    
    public let customHandler:CustomViewHandlers = CustomViewHandlers()
    
    open var backgroundColor:NSColor = .clear {
        didSet {
            if oldValue != self.backgroundColor {
                layer?.backgroundColor = self.backgroundColor.cgColor
                setNeedsDisplay()
            }
        }
    }

    
    @available(OSX 10.12.2, *)
    open override func makeTouchBar() -> NSTouchBar? {
        return viewEnableTouchBar ? super.makeTouchBar() : nil
    }
    
    public var flip:Bool = true
    
    open var border:BorderType?
    

    open override func layout() {
        super.layout()
        if let layout = customHandler.layout {
            layout(self)
        }
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        

        if let displayDelegate = displayDelegate {
            displayDelegate.draw(layer, in: ctx)
        } else {
          //  layer.backgroundColor = backgroundColor.cgColor
           // layer.backgroundColor = self.backgroundColor.cgColor
            
          //  ctx.setShadow(offset: NSMakeSize(5.0, 5.0), blur: 0.0, color: .shadow.cgColor)
            
           // ctx.setFillColor(self.backgroundColor.cgColor)
           // ctx.fill(layer.bounds)
            
            if let border = border {
                ctx.setFillColor(presentation.colors.border.cgColor)
                
                if border.contains(.Top) {
                    ctx.fill(NSMakeRect(0, !self.isFlipped ? NSHeight(self.frame) - .borderSize : 0, NSWidth(self.frame), .borderSize))
                }
                if border.contains(.Bottom) {
                    ctx.fill(NSMakeRect(0, self.isFlipped ? NSHeight(self.frame) - .borderSize : 0, NSWidth(self.frame), .borderSize))
                }
                if border.contains(.Left) {
                    ctx.fill(NSMakeRect(0, 0, .borderSize, NSHeight(self.frame)))
                }
                if border.contains(.Right) {
                    ctx.fill(NSMakeRect(NSWidth(self.frame) - .borderSize, 0, .borderSize, NSHeight(self.frame)))
                }
                
            }
        }
    }
    
    public func setNeedsDisplay() -> Void {
        self.layer?.setNeedsDisplay()
        assertOnMainThread()
    }
    
 
    
    open override var isFlipped: Bool {
        return flip
    }
    

    
    public init() {
        super.init(frame: NSZeroRect)
        assertOnMainThread()
        self.wantsLayer = true
        acceptsTouchEvents = true
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.autoresizesSubviews = false
        layer?.disableActions()
        layer?.backgroundColor = backgroundColor.cgColor
       // self.layer?.delegate = self
      //  self.layer?.isOpaque = false
       // self.autoresizesSubviews = false
       // self.layerContentsRedrawPolicy = .onSetNeedsDisplay
       // self.layer?.drawsAsynchronously = System.drawAsync
    }
    
    override required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        assertOnMainThread()
        acceptsTouchEvents = true
        self.wantsLayer = true
       // self.autoresizesSubviews = false
        layer?.disableActions()
        layer?.backgroundColor = backgroundColor.cgColor
     //   self.layer?.delegate = self
      //  self.layer?.isOpaque = false
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
      //  self.layer?.drawsAsynchronously = System.drawAsync
    }
    
    open override var translatesAutoresizingMaskIntoConstraints: Bool {
        get {
            return true
        }
        set {
            
        }
    }
    
    open func mouseInside() -> Bool {
        return super._mouseInside()
    }
    
    open func change(pos position: NSPoint, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) -> Void  {
        super._change(pos: position, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
        
    open func change(size: NSSize, animated: Bool, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(size: size, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
    }
    open func change(opacity to: CGFloat, animated: Bool = true, _ save:Bool = true, removeOnCompletion: Bool = true, duration:Double = 0.2, timingFunction: String = kCAMediaTimingFunctionEaseOut, completion:((Bool)->Void)? = nil) {
        super._change(opacity: to, animated: animated, save, removeOnCompletion: removeOnCompletion, duration: duration, timingFunction: timingFunction, completion: completion)
        
    }
    
    open override func swipe(with event: NSEvent) {
        super.swipe(with: event)
    }
    
    open override func beginGesture(with event: NSEvent) {
        super.beginGesture(with: event)
    }
    
    open func updateLocalizationAndTheme() {
        for subview in subviews {
            if let subview = subview as? AppearanceViewProtocol {
                subview.updateLocalizationAndTheme()
            }
        }
    }
    
    open override func viewDidMoveToSuperview() {
        if superview != nil {
            guard #available(OSX 10.12, *) else {
           //     self.needsLayout = true
                return
            }
        }
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        if let size = customHandler.size {
            size(newSize)
        }
        guard #available(OSX 10.12, *) else {
            self.needsLayout = true
            return
        }
    }
    
    public func notifySubviewsToLayout(_ subview:NSView) -> Void {
        for sub in subview.subviews {
            sub.needsLayout = true
        }
    }
    
    open override var needsLayout: Bool {
        set {
            super.needsLayout = newValue
            if newValue {
                
                guard #available(OSX 10.12, *) else {
                    layout()
                    notifySubviewsToLayout(self)
                    return
                }

            }
        }
        get {
            return super.needsLayout
        }
    }
    
    
    @objc func layoutInRunLoop() {
        layout()
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        if let origin = customHandler.origin {
            origin(newOrigin)
        }
        guard #available(OSX 10.12, *) else {
            self.needsLayout = true
            return
        }
    }
    
    deinit {
        assertOnMainThread()
    }
    
    
    open var responder:NSResponder? {
        return self
    }
    
    open func setNeedsDisplayLayer() -> Void {
        self.layer?.setNeedsDisplay()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func mouseDown(with event: NSEvent) {
       // self.window?.makeFirstResponder(nil)
        super.mouseDown(with: event)
    }
    
    
    open override func draw(_ dirtyRect: NSRect) {
       
    }
    
    public var hasVisibleModal:Bool {
        if let contentView = self.window?.contentView {
            for subview in contentView.subviews {
                if subview is PopoverBackground {
                    return true
                }
            }
        }
       
        
        return false
    }
    
    open override func copy() -> Any {
        let copy:View = View(frame:bounds)
        copy.layer?.contents = self.layer?.contents
        return copy
    }
    
 
    
    open var kitWindow: Window? {
        return super.window as? Window
    }
    
   
    
}
