//
//  Popover.swift
//  TGUIKit
//
//  Created by keepcoder on 26/09/2016.
//  Copyright © 2016 Telegram. All rights reserved.
//

import Cocoa
import SwiftSignalKitMac

class PopoverBackground: View {
   
}

open class Popover: NSObject {
    
    private var disposable:MetaDisposable = MetaDisposable()
    
    public var animates:Bool = true
    
    public var controller:ViewController?
    
    private weak var control:Control?
    
    public var isShown:Bool = false
    
    public var overlay:OverlayControl!
    private var background:PopoverBackground = PopoverBackground(frame: NSZeroRect)
    
    public var animationStyle:AnimationStyle = AnimationStyle(duration:0.2, function:kCAMediaTimingFunctionSpring)
    
    var readyDisposable:MetaDisposable = MetaDisposable()
    
    required public init(controller:ViewController) {
        self.controller = controller
       // self.background.layer?.backgroundColor = .blueUI.cgColor
        self.background.layer?.shadowOpacity = 0.35
        self.background.layer?.rasterizationScale = CGFloat(System.backingScale)
        self.background.layer?.shouldRasterize = true
        self.background.layer?.isOpaque = true
        self.background.layer?.shadowOffset = NSMakeSize(0, -1)

       // self.background.wantsLayer = false
       
        super.init()
    }
    
 
    
    open func show(for control:Control, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint, contentRect:NSRect = NSMakeRect(7, 7, 0, 0)) -> Void {
        
        if let controller = controller, let parentView = control.window?.contentView {
            
            controller.loadViewIfNeeded()
            controller.viewWillAppear(animates)
            
            while let view = parentView.subviews.last, view.isKind(of: PopoverBackground.self) {
                view.removeFromSuperview()
            }
            
            var signal = controller.ready.get() |> take(1)
            if control.controlState == .Hover {
                signal = signal |> delay(0.2, queue: Queue.mainQueue())
            }
            self.readyDisposable.set(signal.start(next: {[weak self, weak controller, weak parentView] (ready) in
                
                if let strongSelf = self, let controller = controller, let parentView = parentView, (strongSelf.inside() || control.controlState == .Hover || control.controlState == .Highlight) {
                    
                    control.isSelected = true
                    
                    control.kitWindow?.set(escape: {[weak strongSelf] () -> KeyHandlerResult in
                        strongSelf?.hide()
                        return .invoked
                    }, with: strongSelf, priority: .modal)
                    
                    strongSelf.control = control
                    strongSelf.background.flip = false
                    var point:NSPoint = control.convert(NSMakePoint(0, 0), to: parentView)
                    
                    if let edge = edge {
                        
                        switch edge {
                        case .maxX:
                            point.x -= controller.frame.width
                        case .maxY:
                          //  point.x += floorToScreenPixels((control.superview!.frame.width - controller.frame.width) / 2.0)
                            point.y -= controller.frame.height
                            strongSelf.background.flip = true
                        case .minX:
                            point.x -= (controller.frame.width - control.frame.width)
                            point.y -= controller.frame.height
                            strongSelf.background.flip = true
                        default:
                            fatalError("Not Implemented")
                        }
                        
                        
                    }
                    
                    if inset.x != 0 {
                        point.x += (inset.x)

                    }
                    if inset.y != 0 {
                        point.y += inset.y
                    }
                    
                    controller.viewWillAppear(strongSelf.animates)
                    
                    var rect = controller.bounds
                    if !NSIsEmptyRect(contentRect) {
                        rect = contentRect
                    }
                    
                    parentView.layer?.isOpaque = true
                    
                    //.borderSize * 2
                    strongSelf.background.frame = NSMakeRect(point.x, point.y, rect.width + 14, rect.height + 14)
                    strongSelf.background.backgroundColor = .clear
                    strongSelf.background.layer?.cornerRadius = .cornerRadius
                    
                    strongSelf.overlay = OverlayControl(frame: NSMakeRect(contentRect.minX, contentRect.minY, controller.frame.width , controller.frame.height ))
                    strongSelf.overlay.backgroundColor = .white
                    strongSelf.overlay.layer?.cornerRadius = .cornerRadius
                    
                    
                    strongSelf.background.addSubview(strongSelf.overlay)

                    
                    controller.view.layer?.cornerRadius = .cornerRadius
                    controller.view.setFrameOrigin(NSMakePoint(0, 0))
                    
                    
                    strongSelf.overlay.addSubview(controller.view)
                    
                    parentView.addSubview(strongSelf.background)
                    
                    //strongSelf.overlay.center()
                    
                    _ = controller.becomeFirstResponder()
                    
                    strongSelf.isShown = true
                    
                    if let overlay = strongSelf.overlay {
                        if strongSelf.animates {
                            
                            var once:Bool = false
                            
                            for sub in strongSelf.background.subviews {
                                sub.layer?.animate(from: (-strongSelf.background.frame.height) as NSNumber, to: (sub.frame.minY) as NSNumber, keyPath: "position.y", timingFunction: strongSelf.animationStyle.function, duration: strongSelf.animationStyle.duration, removeOnCompletion: true, additive: false, completion:{ [weak controller] (comple) in
                                    if let strongSelf = self, !once {
                                        once = true
                                        controller?.viewDidAppear(strongSelf.animates)
                                    }
                                    
                                    })
                                
                                sub.layer?.animate(from: 0.0 as NSNumber, to: 1.0 as NSNumber, keyPath: "opacity", timingFunction: strongSelf.animationStyle.function, duration: strongSelf.animationStyle.duration)
                            }
                            
                            
                            
                        }
                        
                        let nHandler:(Control) -> Void = { [weak self] _ in
                            
                            let s = Signal<Void,NoError>({ (subscriber) -> Disposable in
                                
                                subscriber.putNext()
                                
                                return ActionDisposable(action: {
                                    
                                });
                                
                            }) |> delay(0.2, queue: Queue.mainQueue())
                            
                            self?.disposable.set(s.start(next: {[weak strongSelf] () in
                                
                                if let strongSelf = strongSelf, control.controlState == .Normal {
                                    if !strongSelf.inside() {
                                        strongSelf.hide()
                                    }
                                }
                                
                            }))
                            
                        }
                        
                        let hHandler:(Control) -> Void = { [weak strongSelf] _ in
                            
                            strongSelf?.disposable.set(nil)
                            
                        }
                        
                        overlay.set(handler: nHandler, for: .Normal)
                        overlay.set(handler: hHandler, for: .Hover)
                        
                        
                        control.set(handler: nHandler, for: .Normal)
                        control.set(handler: hHandler, for: .Hover)
                        
                        
                    }
                }
                
                

            }))
            
        }

    }
    
    
    public func addSubview(_ subview: View) -> Void {
        self.background.addSubview(subview)
    }
    
    func inside() -> Bool {
        
       // return true
        
        if let window = control?.window {
            let g:NSPoint = NSEvent.mouseLocation()
            let w:NSPoint = window.convertFromScreen(NSMakeRect(g.x, g.y, 1, 1)).origin
            //if w.x > background.frame.minX && background
            return NSPointInRect(w, background.frame)
        }
        return false
    }
    

    deinit {
        self.disposable.dispose()
        self.readyDisposable.dispose()
    }
    
    public func hide() -> Void {
        
        isShown = false
        control?.isSelected = false
        overlay?.kitWindow?.remove(object: self, for: .Escape)
        
        overlay?.removeLastStateHandler()
        overlay?.removeLastStateHandler()
        
        control?.removeLastStateHandler()
        control?.removeLastStateHandler()
        
        self.disposable.dispose()
        self.readyDisposable.dispose()
        controller?.viewWillDisappear(true)
        if animates {
            var once:Bool = false
            for sub in background.subviews {
                sub.layer?.animate(from: 1.0 as NSNumber, to: 0.0 as NSNumber, keyPath: "opacity", timingFunction: animationStyle.function, duration: animationStyle.duration, completion:{[weak self] (comple) in
                    if let strongSelf = self, !once {
                        once = true
                        strongSelf.controller?.viewDidDisappear(true)
                        strongSelf.controller?.popover = nil
                        strongSelf.controller = nil
                        strongSelf.background.removeFromSuperview()
                    }
                })
                sub.layer?.opacity = 0.0

            }
            
            
            
        } else {
            self.background.removeFromSuperview()
            self.controller?.popover = nil

        }
    }
    
}

public func hasPopover(_ window:Window) -> Bool {
    for subview in window.contentView!.subviews {
        if subview.isKind(of: Popover.self) {
            return true
        }
    }
    return false
}

public func showPopover(for control:Control, with controller:ViewController, edge:NSRectEdge? = nil, inset:NSPoint = NSZeroPoint) -> Void {
    if controller.popover == nil {
        controller.popover = (controller.popoverClass as! Popover.Type).init(controller: controller)
    }
    
    if let popover = controller.popover {
        popover.show(for: control, edge: edge, inset: inset)
    }
}


