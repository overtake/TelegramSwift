//
//  View.swift
//  TGUIKit
//
//  Created by keepcoder on 06/09/16.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Foundation

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
    public var sizeHandler:((NSSize) ->Void)?
    public var originHandler:((NSPoint) ->Void)?
}

open class View : NSView,CALayerDelegate {
    
    public var animates:Bool = false
    
    public weak var displayDelegate:ViewDisplayDelegate?
    
    public let customHandler:CustomViewHandlers = CustomViewHandlers()
    
    open var backgroundColor:NSColor = .white {
        didSet {
            if oldValue != backgroundColor {
                setNeedsDisplay()
            }
        }
    }
    
    public var flip:Bool = true
    
    public var border:BorderType?
    
    public func removeAllSubviews() -> Void {
        while (self.subviews.count > 0) {
            self.subviews[0].removeFromSuperview();
        }
 
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        if let displayDelegate = displayDelegate {
            displayDelegate.draw(layer, in: ctx)
        } else {
            
          //  ctx.setShadow(offset: NSMakeSize(5.0, 5.0), blur: 0.0, color: .shadow.cgColor)
            
            ctx.setFillColor(self.backgroundColor.cgColor)
            ctx.fill(layer.bounds)
            
            if let border = border {
                
                ctx.setFillColor(NSColor.border.cgColor)
                
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
    }
    
    
    open override var isFlipped: Bool {
        return flip
    }
    

    public init() {
        super.init(frame: NSZeroRect)
        
        self.wantsLayer = true
        self.layer?.delegate = self
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.layer?.drawsAsynchronously = System.drawAsync
    }
    
    override required public init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        
        self.wantsLayer = true
        self.layer?.delegate = self
        self.layerContentsRedrawPolicy = .onSetNeedsDisplay
        self.layer?.drawsAsynchronously = System.drawAsync
    }
    
    open override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        
        if let sizeHandler = customHandler.sizeHandler {
            sizeHandler(newSize)
        }
    }
    
    open override func setFrameOrigin(_ newOrigin: NSPoint) {
        super.setFrameOrigin(newOrigin)
        if let originHandler = customHandler.originHandler {
            originHandler(newOrigin)
        }
    }
    
    
    open func setNeedsDisplayLayer() -> Void {
        self.layer?.setNeedsDisplay()
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    open override func mouseDown(with event: NSEvent) {
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
    
    open var kitWindow: Window? {
        return super.window as? Window
    }
    
}
