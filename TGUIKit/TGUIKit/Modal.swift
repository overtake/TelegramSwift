//
//  Modal.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa

private class ModalBackground : Control {
    fileprivate override func scrollWheel(with event: NSEvent) {
        
    }
}

public class Modal: NSObject {
    
    private var background:ModalBackground
    private var controller:ViewController?
    private var container:View
    private var window:Window

    public init(controller:ViewController, for window:Window) {
        self.controller = controller
        self.window = window
        background = ModalBackground()
        background.backgroundColor = .blackTransparent
        background.layer?.disableActions()
        container = View(frame: controller.bounds)
        container.layer?.cornerRadius = .cornerRadius
        background.addSubview(container)
        super.init()
        
        window.set(escape: {[weak self] () -> KeyHandlerResult in
            self?.close()
            return .invoked
        }, with: self, priority: .high)
        
        background.set(handler: { [weak self] in
            self?.close()
        }, for: .Click)
    }
    
    func close() ->Void {
        
        window.remove(object: self, for: .Escape)
        
        background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: {[weak self] (complete) in
            self?.background.removeFromSuperview()
            self?.controller?.modal = nil
            self?.controller = nil
        })
       
    }
    
    func show() -> Void {
       // if let view
        if let view = window.contentView?.subviews.first {
            background.frame = view.bounds
            background.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
            background.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
            container.center()
            container.autoresizingMask = [.viewMinXMargin,.viewMaxXMargin,.viewMinYMargin,.viewMaxYMargin]
            view.addSubview(background)
        }
    }
    
}


/*
 //
 //  Modal.swift
 //  TGUIKit
 //
 //  Created by keepcoder on 26/09/2016.
 //  Copyright © 2016 Telegram. All rights reserved.
 //
 
 import Cocoa
 
 private class ModalBackground : Control {
 
 }
 
 public class Modal: NSObject {
 
 private var background:ModalBackground
 private var controller:ViewController?
 private var container:View
 private var window:Window
 private var child:Window
 
 public init(controller:ViewController, for window:Window) {
 self.controller = controller
 self.window = window
 background = ModalBackground()
 background.backgroundColor = .blackTransparent
 background.layer?.disableActions()
 container = View(frame: controller.bounds)
 container.layer?.cornerRadius = .cornerRadius
 background.addSubview(container)
 background.layer?.cornerRadius = .cornerRadius
 
 
 child = Window(contentRect: window.frame, styleMask: [], backing: .buffered, defer: true)
 child.backgroundColor = .clear
 super.init()
 
 
 NotificationCenter.default.addObserver(forName: Notification.Name.NSWindowDidResize, object: window, queue: nil, using: {[weak self] (notification) in
 if let strongSelf = self {
 strongSelf.child.setFrame(NSMakeRect(strongSelf.window.frame.minX, strongSelf.window.frame.minY, strongSelf.window.frame.width, strongSelf.window.contentView!.frame.height), display: true)
 }
 })
 
 window.set(escape: {[weak self] () -> KeyHandlerResult in
 self?.close()
 return .invoked
 }, with: self, priority: .high)
 
 background.set(handler: { [weak self] in
 self?.close()
 }, for: .Click)
 }
 
 func close() ->Void {
 
 window.remove(object: self, for: .Escape)
 
 background.layer?.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: {[weak self] (complete) in
 if let strongSelf = self {
 strongSelf.window.removeChildWindow(strongSelf.child)
 strongSelf.background.removeFromSuperview()
 strongSelf.controller?.modal = nil
 strongSelf.controller = nil
 }
 
 })
 
 }
 
 func show() -> Void {
 // if let view
 background.frame = child.contentView!.bounds
 background.layer?.animateAlpha(from: 0, to: 1, duration: 0.2)
 background.autoresizingMask = [.viewWidthSizable,.viewHeightSizable]
 container.center()
 container.autoresizingMask = [.viewMinXMargin,.viewMaxXMargin,.viewMinYMargin,.viewMaxYMargin]
 child.contentView = background
 
 window.addChildWindow(child, ordered: .above)
 
 }
 
 }
 */
