//
//  Node.swift
//  TGUIKit
//
//  Created by keepcoder on 04/10/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac
open class Node: NSObject, ViewDisplayDelegate {
    
    
    public let nodeReady = Promise<Bool>()
    
    
    open var backgroundColor:NSColor? {
        return self.view?.backgroundColor
    }
    
    private let _strongView:View?
    open weak var view:View? {
        didSet {
            if let view = view {
                view.displayDelegate = self
            }
        }
    }
    
    open var size:NSSize = NSZeroSize
    
    open var frame:NSRect {
        get {
            return self.view?.frame ?? NSZeroRect
        }
        set {
            self.view?.frame = newValue
        }
    }
    
    deinit {
        if _strongView != nil {
            assertOnMainThread()
        }
    }
    
    public init(_ view:View? = nil) {
        _strongView = view
        if view != nil {
            assertOnMainThread()
        }
        super.init()
        self.view = view
        
    }
    

    open func setNeedDisplay() -> Void {
        if let view = view {
            view.displayDelegate = self
            view.setNeedsDisplay()
        }
    }
    
    public var measuredWidth:CGFloat = 0
    
    open func measureSize(_ width:CGFloat = 0) -> Void {
        measuredWidth = width
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {

    }
    

    public func removeFromSuperview() -> Void {
        self.view?.removeFromSuperview()
    }
    
    
    open var viewClass:AnyClass {
        return View.self
    }
    
}

