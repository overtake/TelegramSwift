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

struct ChatAccessoryPresentation {
    let background: NSColor
    let title: NSColor
    let enabledText: NSColor
    let disabledText: NSColor
    let border: NSColor
    
    func withUpdatedBackground(_ backgroundColor: NSColor) -> ChatAccessoryPresentation {
        return ChatAccessoryPresentation(background: backgroundColor, title: title, enabledText: enabledText, disabledText: disabledText, border: border)
    }
}

class ChatAccessoryModel: NSObject, ViewDisplayDelegate {
    
    
    public let nodeReady = Promise<Bool>()
    
    
    open var backgroundColor:NSColor {
        didSet {
            self.presentation = presentation.withUpdatedBackground(backgroundColor)
        }
    }
    
    var isSideAccessory: Bool = false
    
    private var _presentation: ChatAccessoryPresentation? = nil
    var presentation: ChatAccessoryPresentation {
        set {
            _presentation = newValue
            view?.needsDisplay = true
        }
        get {
            return _presentation ?? ChatAccessoryPresentation(background: theme.colors.background, title: theme.colors.blueUI, enabledText: theme.colors.text, disabledText: theme.colors.grayText, border: theme.colors.blueFill)
        }
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
    var width: CGFloat = 0
    var sizeToFit: Bool = false
    open var frame:NSRect {
        get {
            return self.view?.frame ?? NSZeroRect
        }
        set {
            self.view?.frame = newValue
            self.view?.needsDisplay = true
        }
    }
    
    deinit {
        if _strongView != nil {
            assertOnMainThread()
        }
    }
    
    public init(_ view:ChatAccessoryView? = nil, presentation: ChatAccessoryPresentation? = nil) {
        _strongView = view
        _presentation = presentation
        if view != nil {
            assertOnMainThread()
        }
        backgroundColor = theme.colors.background
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
    
    var topOffset: CGFloat = 0
    
    
    func measureSize(_ width:CGFloat = 0, sizeToFit: Bool = false) -> Void {
        self.sizeToFit = sizeToFit
        header = TextNode.layoutText(maybeNode: headerNode, headerAttr, nil, 1, .end, NSMakeSize(width - leftInset, 20), nil,false, .left)
        message = TextNode.layoutText(maybeNode: messageNode, messageAttr, nil, 1, .end, NSMakeSize(width - leftInset, 20), nil,false, .left)
        //max(header!.0.size.width,message!.0.size.width) + leftInset
        self.width = width
        size = NSMakeSize(sizeToFit ? max(header!.0.size.width,message!.0.size.width) + leftInset + (isSideAccessory ? 20 : 0) : width, max(34, header!.0.size.height + message!.0.size.height + yInset + (isSideAccessory ? 10 : 0)))
        size.height += topOffset
        
      //  super.measureSize(width)
    }
    
    
    
    
    func draw(_ layer: CALayer, in ctx: CGContext) {
        if let view = view {
            ctx.setFillColor(presentation.background.cgColor)
            ctx.fill(layer.bounds)
            
            ctx.setFillColor(presentation.border.cgColor)
            
            let radius:CGFloat = 1.0
            ctx.fill(NSMakeRect((isSideAccessory ? 10 : 0), radius + (isSideAccessory ? 5 : 0) + topOffset, 2, size.height - topOffset - radius * 2 - (isSideAccessory ? 10 : 0)))
            ctx.fillEllipse(in: CGRect(origin: CGPoint(x: (isSideAccessory ? 10 : 0), y: (isSideAccessory ? 5 : 0) + topOffset), size: CGSize(width: radius + radius, height: radius + radius)))
            ctx.fillEllipse(in: CGRect(origin: CGPoint(x: (isSideAccessory ? 10 : 0), y: size.height - radius * 2 -  (isSideAccessory ? 5 : 0)), size: CGSize(width: radius + radius, height: radius + radius)))
            
            if  let header = header, let message = message {
                header.1.draw(NSMakeRect(leftInset + (isSideAccessory ? 10 : 0), (isSideAccessory ? 5 : 0) + topOffset, header.0.size.width, header.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor, backgroundColor: backgroundColor)
                if headerAttr == nil {
                    message.1.draw(NSMakeRect(leftInset + (isSideAccessory ? 10 : 0), floorToScreenPixels(scaleFactor: view.backingScaleFactor, topOffset + (size.height - topOffset - message.0.size.height)/2), message.0.size.width, message.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor, backgroundColor: backgroundColor)
                } else {
                    message.1.draw(NSMakeRect(leftInset + (isSideAccessory ? 10 : 0), header.0.size.height + yInset + (isSideAccessory ? 5 : 0) + topOffset, message.0.size.width, message.0.size.height), in: ctx, backingScaleFactor: view.backingScaleFactor, backgroundColor: backgroundColor)
                }
            }
        }
        
    }

}
