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
    
    open var view:View? {
        didSet {
            self.view?.displayDelegate = self
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
    
    public init(_ view:View? = nil) {
        super.init()
        self.view = view
    }
    

    

    open func setNeedDisplay() -> Void {
        self.view?.displayDelegate = self
        self.view?.setNeedsDisplay()
    }
    
    public var measuredWidth:CGFloat = 0
    
    open func measureSize(_ width:CGFloat = 0) -> Void {
        measuredWidth = width
    }
    
    open func draw(_ layer: CALayer, in ctx: CGContext) {
        ctx.setFillColor(backgroundColor!.cgColor)
        ctx.fill(layer.bounds)
    }
    

    public func removeFromSuperview() -> Void {
        self.view?.removeFromSuperview()
    }
    
    
    open var viewClass:AnyClass {
        return View.self
    }
    
}
