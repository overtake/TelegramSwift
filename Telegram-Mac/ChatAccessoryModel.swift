//
//  ChatAccessoryModel.swift
//  Telegram
//
//  Created by keepcoder on 01/02/2017.
//  Copyright © 2017 Telegram. All rights reserved.
//

import Cocoa
import TGUIKit
import SwiftSignalKitMac

class ChatAccessoryView : Control {
    var imageView: TransformImageView?
}

class ChatAccessoryModel: NSObject, ViewDisplayDelegate {
    
    
    public let nodeReady = Promise<Bool>()
    
    
    open var backgroundColor:NSColor {
        return view?.backgroundColor ?? theme.colors.background
    }
    
    private let _strongView:ChatAccessoryView?
    open weak var view:ChatAccessoryView? {
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
    
    public init(_ view:ChatAccessoryView? = nil) {
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
            view.needsDisplay = true
        }
    }
    

    
    
    public func removeFromSuperview() -> Void {
        self.view?.removeFromSuperview()
    }
    
    
    open var viewClass:AnyClass {
        return View.self
    }
    
    
    let yInset:CGFloat = 2
    var leftInset:CGFloat {
        return 8
    }
    
    var headerAttr:NSAttributedString?
    var messageAttr:NSAttributedString?
    
    private var headerNode:TextNode = TextNode()
    private var messageNode:TextNode = TextNode()
    
    var header:(TextNodeLayout,  TextNode)?
    var message:(TextNodeLayout, TextNode)?
    
    func measureSize(_ width:CGFloat = 0) -> Void {
        header = TextNode.layoutText(maybeNode: headerNode, headerAttr, nil, 1, .end, NSMakeSize(width - leftInset, 20), nil,false, .left)
        message = TextNode.layoutText(maybeNode: messageNode, messageAttr, nil, 1, .end, NSMakeSize(width - leftInset, 20), nil,false, .left)
        //max(header!.0.size.width,message!.0.size.width) + leftInset
        size = NSMakeSize(width, max(34, header!.0.size.height + message!.0.size.height + yInset))
      //  super.measureSize(width)
    }
    
    
    
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        if let view = view {
            ctx.setFillColor(backgroundColor.cgColor)
            ctx.fill(layer.bounds)
            
            ctx.setFillColor(theme.colors.blueFill.cgColor)
            
            let radius:CGFloat = 1.0
            ctx.fill(NSMakeRect(0, radius, 2, layer.bounds.height - radius * 2))
            ctx.fillEllipse(in: CGRect(origin: CGPoint(), size: CGSize(width: radius + radius, height: radius + radius)))
            ctx.fillEllipse(in: CGRect(origin: CGPoint(x: 0.0, y: layer.bounds.height - radius * 2), size: CGSize(width: radius + radius, height: radius + radius)))
            
            if  let header = header, let message = message {
                header.1.draw(NSMakeRect(leftInset, 0, header.0.size.width, header.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor)
                if headerAttr == nil {
                    message.1.draw(NSMakeRect(leftInset, floorToScreenPixels((size.height - message.0.size.height)/2), message.0.size.width, message.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor)
                } else {
                    message.1.draw(NSMakeRect(leftInset, header.0.size.height + yInset, message.0.size.width, message.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor)
                }
            }
        }
        
    }

}
